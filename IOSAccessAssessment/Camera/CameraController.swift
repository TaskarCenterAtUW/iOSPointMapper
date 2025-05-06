//
//  CameraController.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import AVFoundation
import UIKit
import Vision
import CoreGraphics

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
    func onNewData(cameraPixelBuffer: CVPixelBuffer, depthPixelBuffer: CVPixelBuffer?)
}

enum CameraControllerError: Error, LocalizedError {
    case cameraUnavailable
    case depthDataUnavailable
    
    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "Camera is unavailable."
        case .depthDataUnavailable:
            return "Depth data is unavailable."
        }
    }
}

/**
 CameraController is responsible for managing the camera and depth data capture session.
 */
class CameraController: NSObject, ObservableObject {
    
    enum ConfigurationError: Error {
        case lidarDeviceUnavailable
        case requiredDeviceUnavailable
        case requiredFormatUnavailable
    }
    private let videoDataOutputQueue = DispatchQueue(label: "videoQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private(set) var captureSession: AVCaptureSession!
    private(set) var captureDevice: AVCaptureDevice!
    
    private var isLidarDeviceAvailable: Bool = false
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
        captureDevice = getCameraDevice()
        guard let captureDevice = captureDevice else {
            throw ConfigurationError.requiredDeviceUnavailable
        }
        isLidarDeviceAvailable = checkLidarAvailability()
        
        let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        captureSession.addInput(deviceInput)
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
            self.captureDevice.configureDesiredFrameRate(15)
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
        
        guard let cameraPixelBuffer = syncedVideoData.sampleBuffer.imageBuffer else { return }
//        let cameraImage = orientAndFixCameraFrame(cameraPixelBuffer)
        if (!isLidarDeviceAvailable) {
            delegate?.onNewData(cameraPixelBuffer: cameraPixelBuffer, depthPixelBuffer: nil)
            return
        }
        
        guard let syncedDepthData = synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData else { return }
        let depthData = syncedDepthData.depthData
        let depthPixelBuffer = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32).depthDataMap
//        let depthImage = orientAndFixDepthFrame(depthPixelBuffer)
        
        delegate?.onNewData(cameraPixelBuffer: cameraPixelBuffer, depthPixelBuffer: depthPixelBuffer)
    }
}
