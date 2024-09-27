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
        
        guard let pixelBuffer = syncedVideoData.sampleBuffer.imageBuffer else { return } //1920 \times 1080
        let context = CIContext()
        // Convert to CIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        // Crop center 1024 \times 1024
        let croppedCIImage = ciImage.croppedToCenter(size: croppedSize) // 1024 \times 1024
        // Convert to CGImage
        guard let cgImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else { return }
        
        let depthData = syncedDepthData.depthData
        // Process depth data
        let depthPixelBuffer = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
        
        let depthWidth = CVPixelBufferGetWidth(depthPixelBuffer)
        let depthHeight = CVPixelBufferGetHeight(depthPixelBuffer)
        print("Depth Dimensions \(depthWidth), \(depthHeight)")

        let depthAspectRatio = depthWidth > depthHeight
        let depthSideLength = min(depthWidth, depthHeight)
        // TODO: Check why does this lead to an error on orientation change
        let scale: Int = Int(floor(1024 / CGFloat(depthSideLength)) + 1)
        guard let croppedDepthPixelBuffer = resizeAndCropPixelBuffer(depthPixelBuffer, targetSize: CGSize(width: depthWidth * scale, height: depthHeight * scale), cropSize: croppedSize) else { return }
        
//        let croppedDepthWidth = CVPixelBufferGetWidth(croppedDepthPixelBuffer)
//        let croppedDepthHeight = CVPixelBufferGetHeight(croppedDepthPixelBuffer)
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

extension CIImage {
    func croppedToCenter(size: CGSize) -> CIImage {
        let x = (extent.width - size.width) / 2
        let y = (extent.height - size.height) / 2
//        print("before: \(x), \(y)")
        let cropRect = CGRect(x: x, y: y, width: size.width, height: size.height)
        return cropped(to: cropRect)
    }
}

private func cropCenterOfPixelBuffer(_ pixelBuffer: CVPixelBuffer, cropSize: CGSize) -> CVPixelBuffer? {
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
//    print("After size: \(width), \(height)")
    let cropX = (Float(width) - Float(cropSize.width)) / 2
//    let cropX = (Float(width) - Float(cropSize.width) - (256 + 128 + 64)) / 2
    let cropY = (Float(height) - Float(cropSize.height)) / 2
//    print("after: \(cropX), \(cropY)")
    var croppedPixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(cropSize.width), Int(cropSize.height), CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &croppedPixelBuffer)
    guard status == kCVReturnSuccess, let outputBuffer = croppedPixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(outputBuffer, [])

    let inputBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
    let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer)!

    let inputBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputBuffer)

    let cropXOffset = Int(cropX) * 4
    let cropYOffset = Int(cropY) * inputBytesPerRow
    for y in 0..<Int(cropSize.height) {
        let inputRow = inputBaseAddress.advanced(by: cropYOffset + cropXOffset + y * inputBytesPerRow)
        let outputRow = outputBaseAddress.advanced(by: y * outputBytesPerRow)
        memcpy(outputRow, inputRow, Int(cropSize.width) * 4)
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    CVPixelBufferUnlockBaseAddress(outputBuffer, [])

    return outputBuffer
}

import Accelerate

private func resizePixelBuffer(_ pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
    var resizedPixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, CVPixelBufferGetPixelFormatType(pixelBuffer), nil, &resizedPixelBuffer)
    guard status == kCVReturnSuccess, let outputBuffer = resizedPixelBuffer else { return nil }

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    CVPixelBufferLockBaseAddress(outputBuffer, [])

    let inputBaseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)!
    let outputBaseAddress = CVPixelBufferGetBaseAddress(outputBuffer)!

    var inBuffer = vImage_Buffer(data: inputBaseAddress,
                                 height: vImagePixelCount(CVPixelBufferGetHeight(pixelBuffer)),
                                 width: vImagePixelCount(CVPixelBufferGetWidth(pixelBuffer)),
                                 rowBytes: CVPixelBufferGetBytesPerRow(pixelBuffer))

    var outBuffer = vImage_Buffer(data: outputBaseAddress,
                                  height: vImagePixelCount(height),
                                  width: vImagePixelCount(width),
                                  rowBytes: CVPixelBufferGetBytesPerRow(outputBuffer))

    let scaleError = vImageScale_ARGB8888(&inBuffer, &outBuffer, nil, vImage_Flags(0))
    guard scaleError == kvImageNoError else { return nil }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    CVPixelBufferUnlockBaseAddress(outputBuffer, [])

    return outputBuffer
}

private func resizeAndCropPixelBuffer(_ pixelBuffer: CVPixelBuffer, targetSize: CGSize, cropSize: CGSize) -> CVPixelBuffer? {
    guard let resizedPixelBuffer = resizePixelBuffer(pixelBuffer, width: Int(targetSize.width), height: Int(targetSize.height)) else {
        return nil
    }
    return cropCenterOfPixelBuffer(resizedPixelBuffer, cropSize: cropSize)
}

