//
//  CameraController.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import AVFoundation
import UIKit
import Vision

// Used as delegate by the CameraController
protocol CaptureDataReceiver: AnyObject {
    func onNewData(cgImage: CGImage, cvPixel: CVPixelBuffer)
    func onNewPhotoData()
}

class CameraController: NSObject, ObservableObject {
    
    enum ConfigurationError: Error {
        case lidarDeviceUnavailable
        case requiredFormatUnavailable
    }
    
    private let videoDataOutputQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private(set) var captureSession: AVCaptureSession!
    
    private var photoOutput: AVCapturePhotoOutput!
    private var depthDataOutput: AVCaptureDepthDataOutput!
    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var outputVideoSync: AVCaptureDataOutputSynchronizer!
    
    weak var delegate: CaptureDataReceiver?
    
    var isFilteringEnabled = true {
        didSet {
            depthDataOutput?.isFilteringEnabled = isFilteringEnabled
        }
    }
    
    override init() {
        super.init()
        do {
            try setupSession()
        } catch {
            fatalError("Unable to configure the capture session.")
        }
    }
    
    // Initialize the captureSession and set its configuration
    private func setupSession() throws {
        captureSession = AVCaptureSession()
        
        // Configure the capture session.
        captureSession.beginConfiguration()
        
        captureSession.sessionPreset = .inputPriority
        
        try setupCaptureInput()
        setupCaptureOutputs()
        
        // Finalize the capture session configuration.
        captureSession.commitConfiguration()
    }
    
    // Add a device input to the capture session.
    private func setupCaptureInput() throws {
        // Look up the LiDAR camera. Generally, only present at the back camera
        guard let device = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: .back) else {
            throw ConfigurationError.lidarDeviceUnavailable
        }
        
        let deviceInput = try AVCaptureDeviceInput(device: device)
        captureSession.addInput(deviceInput)
    }
    
    private func setupCaptureOutputs() {
        // Create an object to output video sample buffers.
        videoDataOutput = AVCaptureVideoDataOutput()
        captureSession.addOutput(videoDataOutput)
        
        // Create an object to output depth data.
        depthDataOutput = AVCaptureDepthDataOutput()
        depthDataOutput.isFilteringEnabled = isFilteringEnabled
        captureSession.addOutput(depthDataOutput)
        
        // Create an object to synchronize the delivery of depth and video data.
        outputVideoSync = AVCaptureDataOutputSynchronizer(dataOutputs: [depthDataOutput, videoDataOutput])
        outputVideoSync.setDelegate(self, queue: videoDataOutputQueue)
        
        // Create an object to output photos.
        photoOutput = AVCapturePhotoOutput()
        photoOutput.maxPhotoQualityPrioritization = .quality
        captureSession.addOutput(photoOutput)
        
        // Enable delivery of depth data after adding the output to the capture session.
        photoOutput.isDepthDataDeliveryEnabled = true
    }
    
    func startStream() {
        DispatchQueue.main.async {
            self.captureSession.startRunning()
        }
    }
    
    func stopStream() {
        captureSession.stopRunning()
    }
}

// MARK: Output Synchronizer Delegate
extension CameraController: AVCaptureDataOutputSynchronizerDelegate {
    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer,
                                didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        // Retrieve the synchronized depth and sample buffer container objects.
        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData,
              let syncedVideoData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else { return }
        
        var imageRequestHandler: VNImageRequestHandler
        
        guard let pixelBuffer = syncedVideoData.sampleBuffer.imageBuffer else { return } //1920 \times 1080
        let context = CIContext()
        // Convert to CIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Crop center 256 \times 256
        let croppedCIImage = ciImage.croppedToCenter(size: CGSize(width: 1024, height: 1024)) // 1024 \times 1024
        // Convert to CGImage
        guard let cgImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else { return }
        
        let depthData = syncedDepthData.depthData
        // Process depth data
        let depthPixelBuffer = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
        
        let depthWidth = CVPixelBufferGetWidth(depthPixelBuffer)
        let depthHeight = CVPixelBufferGetHeight(depthPixelBuffer)

        let depthAspectRatio = depthWidth > depthHeight
        let scale: Int
        if depthAspectRatio {
            scale = Int(floor(1024 / CGFloat(depthHeight)) + 1)
        } else {
            scale = Int(floor(1024 / CGFloat(depthWidth)) + 1)
        }
        guard let croppedDepthPixelBuffer = resizeAndCropPixelBuffer(depthPixelBuffer, targetSize: CGSize(width: depthWidth * scale, height: depthHeight * scale), cropSize: CGSize(width: 1024, height: 1024)) else { return }
        
        let croppedDepthWidth = CVPixelBufferGetWidth(croppedDepthPixelBuffer)
        let croppedDepthHeight = CVPixelBufferGetHeight(croppedDepthPixelBuffer)
//        print("After After size: \(croppedDepthWidth), \(croppedDepthHeight)")
        imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .right, options: [:])
        
        delegate?.onNewData(cgImage: cgImage, cvPixel: croppedDepthPixelBuffer)
        
        do {
            try imageRequestHandler.perform(SegmentationViewController.requests)
        } catch {
            print(error)
        }
    }
}

// MARK: Photo Capture Delegate
extension CameraController: AVCapturePhotoCaptureDelegate {
    
    func capturePhoto() {
        var photoSettings: AVCapturePhotoSettings
        if  photoOutput.availablePhotoPixelFormatTypes.contains(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            photoSettings = AVCapturePhotoSettings(format: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ])
        } else {
            photoSettings = AVCapturePhotoSettings()
        }
        stopStream()
        // Capture depth data with this photo capture.
        photoSettings.isDepthDataDeliveryEnabled = true
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        // Retrieve the image and depth data.
        guard let pixelBuffer = photo.pixelBuffer,
              let depthData = photo.depthData,
              let cameraCalibrationData = depthData.cameraCalibrationData else { return }
        
        // Stop the stream until the user returns to streaming mode.
//        stopStream()
        
        delegate?.onNewPhotoData()
    }
}

