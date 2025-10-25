//
//  ARCameraManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/22/25.
//

import ARKit
import Combine

enum ARCameraManagerError: Error, LocalizedError {
    case sessionConfigurationFailed
    case pixelBufferPoolCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .sessionConfigurationFailed:
            return "AR session configuration failed."
        case .pixelBufferPoolCreationFailed:
            return "Failed to create pixel buffer pool."
        }
    }
}

final class ARCameraManager: NSObject, ObservableObject, ARSessionDelegate {
    @Published var isProcessingCapturedResult = false
    
    @Published var deviceOrientation = UIDevice.current.orientation {
        didSet {
        }
    }
    
    var frameRate: Int = 15
    var lastFrameTime: TimeInterval = 0
    
    override init() {
    }
    
    func setFrameRate(_ frameRate: Int) {
        self.frameRate = frameRate
    }
    
    func checkFrameWithinFrameRate(frame: ARFrame) -> Bool {
        let currentTime = frame.timestamp
        let withinFrameRate = currentTime - lastFrameTime >= (1.0 / Double(frameRate))
        if withinFrameRate {
            lastFrameTime = currentTime
        }
        return withinFrameRate
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard checkFrameWithinFrameRate(frame: frame) else {
            return
        }
        
        let pixelBuffer = frame.capturedImage
        
        let cIImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cameraTransform = frame.camera.transform
        let cameraIntrinsics = frame.camera.intrinsics
        
        let depthBuffer = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap
        let depthConfidenceBuffer = frame.smoothedSceneDepth?.confidenceMap ?? frame.sceneDepth?.confidenceMap
        
        
    }
}
