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
    // TODO: Check if the videoDataOutputQueue or the DataOutputSynchronizer can be optimized
    //  Either by moving some Image Processing functionality to the GPU
    //  or by reducing the number of frames that are processed
    private let videoDataOutputQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private(set) var captureSession: AVCaptureSession!
    
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
        // TODO: Make the depth data information somewhat optional so that the app can still be tested for its segmentation.
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
    }
    
    func startStream() {
        DispatchQueue.global(qos: .userInitiated).async {
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
        
        let croppedSize: CGSize = CGSize(width: 1024, height: 1024)
        
        // TODO: Check if it is more performant to use CVPixelBuffer for all the cropping and other conversions
        //  and then convert to CIImage/CGIImage where needed.
        // NOTE: The CGIImage is actually never directly used. It is converted to a UIImage.
        //  Thus, check if we can directly send the CVPixelBuffer instead
        // Get the image buffer, convert to CIImage to crop, and convert to CGImage to send to vision model
        // NOTE: CVPixelBuffer may not be appropriate due to it being for video frame data.
        guard let pixelBuffer = syncedVideoData.sampleBuffer.imageBuffer else { return } //1920 \times 1080
        let context = CIContext()
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let croppedCIImage = ciImage.croppedToCenter(size: croppedSize) // 1024 \times 1024
        guard let cgImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else { return }
        
        // Get pixel buffer to process depth data,
        // TODO: Conversely, check if it is more convenient to convert the CVPixelBuffer to CIImage,
        //  perform the resize and crop, then convert back to CVPixelBuffer
        let depthData = syncedDepthData.depthData
        let depthPixelBuffer = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
        let depthWidth = CVPixelBufferGetWidth(depthPixelBuffer)
        let depthHeight = CVPixelBufferGetHeight(depthPixelBuffer)
        let depthSideLength = min(depthWidth, depthHeight)
        // TODO: Check why does this lead to an error on orientation change
        let scale: Int = Int(floor(1024 / CGFloat(depthSideLength)) + 1)
        guard let croppedDepthPixelBuffer = resizeAndCropPixelBuffer(depthPixelBuffer, targetSize: CGSize(width: depthWidth * scale, height: depthHeight * scale), cropSize: croppedSize) else { return }
        
//        let croppedDepthWidth = CVPixelBufferGetWidth(croppedDepthPixelBuffer)
//        let croppedDepthHeight = CVPixelBufferGetHeight(croppedDepthPixelBuffer)
        imageRequestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: .right, options: [:])
        
        delegate?.onNewData(cgImage: cgImage, cvPixel: croppedDepthPixelBuffer)
        
        do {
            try imageRequestHandler.perform(SegmentationViewController.requests)
        } catch {
            print(error)
        }
    }
}
