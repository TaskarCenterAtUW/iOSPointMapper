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

enum ARCameraManagerConstants {
    enum Payload {
        static let isCameraStopped = "isStopped"
        static let cameraTransform = "cameraTransform"
        static let cameraIntrinsics = "cameraIntrinsics"
        static let originalImageSize = "originalImageSize"
    }
}

final class ARCameraManager: NSObject, ObservableObject, ARSessionDelegate {
    var segmentationPipeline: SegmentationARPipeline
    @Published var isProcessingCapturedResult = false
    
    @Published var deviceOrientation = UIDevice.current.orientation {
        didSet {
        }
    }
    var cancellables = Set<AnyCancellable>()
    
    var frameRate: Int = 15
    var lastFrameTime: TimeInterval = 0
    
    // Properties for processing camera and depth frames
    var ciContext = CIContext(options: nil)
    var cameraPixelBufferPool: CVPixelBufferPool? = nil
    var cameraColorSpace: CGColorSpace? = nil
//    var depthPixelBufferPool: CVPixelBufferPool? = nil
//    var depthColorSpace: CGColorSpace? = nil
    
    init(segmentationPipeline: SegmentationARPipeline) throws {
        self.segmentationPipeline = segmentationPipeline
        
        super.init()
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.deviceOrientation = UIDevice.current.orientation
        }.store(in: &cancellables)
        
        do {
            try setUpPixelBufferPools()
        } catch let error as ARCameraManagerError {
            throw error
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard checkFrameWithinFrameRate(frame: frame) else {
            return
        }
        if isProcessingCapturedResult {
            return
        }
        isProcessingCapturedResult = true
        
        let pixelBuffer = frame.capturedImage
        let cameraTransform = frame.camera.transform
        let cameraIntrinsics = frame.camera.intrinsics
        
        let depthBuffer = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap
        let depthConfidenceBuffer = frame.smoothedSceneDepth?.confidenceMap ?? frame.sceneDepth?.confidenceMap
        
        let exifOrientation: CGImagePropertyOrientation = exifOrientationForCurrentDevice()
        
        processCameraBuffer(
            pixelBuffer: pixelBuffer, orientation: exifOrientation, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
    }
    
    private func processCameraBuffer(
        pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) {
        var cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        let originalCameraImageSize = CGSize(width: cameraImage.extent.width, height: cameraImage.extent.height)
        let croppedSize = SegmentationConfig.cocoCustom11Config.inputSize
        
        cameraImage = cameraImage.oriented(orientation)
        cameraImage = CIImageUtils.centerCropAspectFit(cameraImage, to: croppedSize)
        
        let renderedCameraPixelBuffer = renderCIImageToPixelBuffer(
            cameraImage,
            size: croppedSize,
            pixelBufferPool: cameraPixelBufferPool!,
            colorSpace: cameraColorSpace
        )
        guard let renderedCameraPixelBufferUnwrapped = renderedCameraPixelBuffer else {
            return
        }
        let renderedCameraImage = CIImage(cvPixelBuffer: renderedCameraPixelBufferUnwrapped)
        
        let additionalPayload = getAdditionalPayload(
            cameraTransform: cameraTransform, intrinsics: cameraIntrinsics, originalCameraImageSize: originalCameraImageSize
        )
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
    
    private func exifOrientationForCurrentDevice() -> CGImagePropertyOrientation {
        // If you lock to portrait + back camera, returning .right is enough.
        switch UIDevice.current.orientation {
        case .landscapeLeft:  return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right // portrait (back camera)
        }
    }
    
    private func getAdditionalPayload(
        cameraTransform: simd_float4x4, intrinsics: simd_float3x3, originalCameraImageSize: CGSize
    ) -> [String: Any] {
        var additionalPayload: [String: Any] = [:]
        additionalPayload[ARCameraManagerConstants.Payload.cameraTransform] = cameraTransform
        additionalPayload[ARCameraManagerConstants.Payload.cameraIntrinsics] = intrinsics
        additionalPayload[ARCameraManagerConstants.Payload.originalImageSize] = originalCameraImageSize
        return additionalPayload
    }
}

// Functions to orient and fix the camera and depth frames
extension ARCameraManager {
    func setUpPixelBufferPools() throws {
        // Set up the pixel buffer pool for future flattening of camera images
        let cameraPixelBufferPoolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 5
        ]
        let cameraPixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Constants.SelectedSegmentationConfig.inputSize.width,
            kCVPixelBufferHeightKey as String: Constants.SelectedSegmentationConfig.inputSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let cameraStatus = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            cameraPixelBufferPoolAttributes as CFDictionary,
            cameraPixelBufferAttributes as CFDictionary,
            &cameraPixelBufferPool
        )
        guard cameraStatus == kCVReturnSuccess else {
            throw ARCameraManagerError.pixelBufferPoolCreationFailed
        }
        cameraColorSpace = CGColorSpaceCreateDeviceRGB()
    }
    
    private func renderCIImageToPixelBuffer(
        _ image: CIImage, size: CGSize,
        pixelBufferPool: CVPixelBufferPool, colorSpace: CGColorSpace? = nil) -> CVPixelBuffer? {
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBufferOut)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
            return nil
        }
        
        ciContext.render(image, to: pixelBuffer, bounds: CGRect(origin: .zero, size: size), colorSpace: colorSpace)
        return pixelBuffer
    }
}
