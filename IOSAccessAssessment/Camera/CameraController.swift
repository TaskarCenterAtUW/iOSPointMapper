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
    /**
        Called when new data is available from the camera and depth sensor.
        # Parameters
        - cameraImage: The image from the camera.
        - depthImage: The image from the depth sensor.
     
        # Discussion
        The depth image is made optional in case the LiDAR sensor is not present
            
     */
    func onNewData(cameraImage: CIImage, depthImage: CIImage?)
    
    /**
        Called to return info on if the LiDAR sensor is available.
     */
    func getLidarAvailability(isLidarAvailable: Bool)
}

class CameraController: NSObject, ObservableObject {
    
    enum ConfigurationError: Error {
        case lidarDeviceUnavailable
        case requiredDeviceUnavailable
        case requiredFormatUnavailable
    }
    private let videoDataOutputQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private(set) var captureSession: AVCaptureSession!
    private(set) var captureDevice: AVCaptureDevice!
    
    private var isLidarDeviceAvailable: Bool!
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
        let deviceAndDepthFlag = try getDeviceAndDepthFlag()
        captureDevice = deviceAndDepthFlag.device
        isLidarDeviceAvailable = deviceAndDepthFlag.hasLidar
        delegate?.getLidarAvailability(isLidarAvailable: deviceAndDepthFlag.hasLidar)
        
        
        
        let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        captureSession.addInput(deviceInput)
    }
    
    // Get the best available device
    private func getDeviceAndDepthFlag() throws -> (device: AVCaptureDevice, hasLidar: Bool) {
        let deviceTypes: [(AVCaptureDevice.DeviceType, Bool)] = [
                (.builtInLiDARDepthCamera, true),
                (.builtInTripleCamera, false),
                (.builtInDualCamera, false),
                (.builtInWideAngleCamera, false)
        ]
        for (deviceType, hasLidar) in deviceTypes {
            if let device = AVCaptureDevice.default(deviceType, for: .video, position: .back) {
                return (device: device, hasLidar: hasLidar)
            }
        }
        throw ConfigurationError.requiredDeviceUnavailable
    }
    
    private func setupCaptureOutputs() {
        var dataOutputs: [AVCaptureOutput] = []
        // Create an object to output video sample buffers.
        videoDataOutput = AVCaptureVideoDataOutput()
        captureSession.addOutput(videoDataOutput)
        dataOutputs.append(videoDataOutput)
        
        // Create an object to output depth data.
        if (isLidarDeviceAvailable) {
            depthDataOutput = AVCaptureDepthDataOutput()
            depthDataOutput.isFilteringEnabled = isFilteringEnabled
            captureSession.addOutput(depthDataOutput)
            dataOutputs.append(depthDataOutput)
        }
        
        // Create an object to synchronize the delivery of depth and video data.
        outputVideoSync = AVCaptureDataOutputSynchronizer(dataOutputs: dataOutputs)
        outputVideoSync.setDelegate(self, queue: videoDataOutputQueue)
    }
    
    func startStream() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            self.captureDevice.configureDesiredFrameRate(5)
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
        guard let syncedVideoData = synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else { return }
        
        // FIXME: This temporary solution of inverting the height and the width need to fixed ASAP
        let croppedSize: CGSize = CGSize(
            width: Constants.ClassConstants.inputSize.height,
            height: Constants.ClassConstants.inputSize.width
        )
        
        // TODO: Check if it is more performant to use CVPixelBuffer for all the cropping and other conversions
        //  and then convert to CIImage/CGIImage where needed.
        // NOTE: The CGIImage is actually never directly used. It is converted to a UIImage.
        //  Thus, check if we can directly send the CVPixelBuffer instead
        // Get the image buffer, convert to CIImage to crop, and convert to CGImage to send to vision model
        // NOTE: CVPixelBuffer may not be appropriate due to it being for video frame data.
        guard let pixelBuffer = syncedVideoData.sampleBuffer.imageBuffer else { return } //1920 \times 1080
        let context = CIContext()
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cameraImage = ciImage.croppedToCenter(size: croppedSize)
//        guard let cameraImage = context.createCGImage(croppedCIImage, from: croppedCIImage.extent) else { return }
        
        // Get pixel buffer to process depth data,
        // TODO: Conversely, check if it is more convenient to convert the CVPixelBuffer to CIImage,
        //  perform the resize and crop, then convert back to CVPixelBuffer
//        var finalDepthPixelBuffer: CVPixelBuffer
        var depthImage: CIImage
        if (isLidarDeviceAvailable) {
            guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData else { return }
            let depthData = syncedDepthData.depthData
            let depthPixelBuffer = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
            let depthWidth = CVPixelBufferGetWidth(depthPixelBuffer)
            let depthHeight = CVPixelBufferGetHeight(depthPixelBuffer)
            let depthSideLength = min(depthWidth, depthHeight)
            // TODO: Check why does this lead to an error on orientation change
            let scale: Int = Int(floor(1024 / CGFloat(depthSideLength)) + 1)
            
            depthImage = CIImage(cvPixelBuffer: depthPixelBuffer).resized(to: CGSize(width: depthWidth * scale, height: depthHeight * scale)).croppedToCenter(size: croppedSize)
//            guard let croppedDepthPixelBuffer = resizeAndCropPixelBuffer(depthPixelBuffer, targetSize: CGSize(width: depthWidth * scale, height: depthHeight * scale), cropSize: croppedSize) else { return }
//            finalDepthPixelBuffer = croppedDepthPixelBuffer
        } else {
            // LiDAR is not available, so create a CVPixelBuffer filled with 0s
            depthImage = CIImage(cvPixelBuffer: createBlankDepthPixelBuffer(targetSize: croppedSize)!)
//            finalDepthPixelBuffer = createBlankDepthPixelBuffer(targetSize: croppedSize)!
        }
        
        delegate?.onNewData(cameraImage: cameraImage, depthImage: depthImage)
    }
}
