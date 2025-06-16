//
//  ARCameraManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/22/25.
//

import ARKit
import Combine

final class ARCameraManager: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()
    
    var sharedImageData: SharedImageData?
    var segmentationPipeline: SegmentationARPipeline?
    
    @Published var deviceOrientation = UIDevice.current.orientation {
        didSet {
//            print("Orientation changed to \(deviceOrientation)")
        }
    }
    @Published var isProcessingCapturedResult = false
    @Published var dataAvailable = false
    var isDepthSupported: Bool = false
    
    // Frame rate-related properties
    var frameRate: Int = 5
    var lastFrameTime: TimeInterval = 0
    
    // Temporary image data
    @Published var cameraUIImage: UIImage?
    @Published var depthUIImage: UIImage?
    
    var cancellables = Set<AnyCancellable>()
    
    var ciContext = CIContext(options: nil)
    var cameraPixelBufferPool: CVPixelBufferPool? = nil
    var cameraColorSpace: CGColorSpace? = nil
    var depthPixelBufferPool: CVPixelBufferPool? = nil
    var depthColorSpace: CGColorSpace? = nil
    
    init(sharedImageData: SharedImageData, segmentationPipeline: SegmentationARPipeline) {
        self.sharedImageData = sharedImageData
        self.segmentationPipeline = segmentationPipeline
        super.init()
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.deviceOrientation = UIDevice.current.orientation
        }.store(in: &cancellables)
        session.delegate = self
        runSession()
        
        do {
            try setUpPixelBufferPools()
        } catch {
            fatalError("Failed to set up pixel buffer pools: \(error.localizedDescription)")
        }
    }
    
    func runSession() {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics = [.smoothedSceneDepth]
            isDepthSupported = true
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics = [.sceneDepth]
            isDepthSupported = true
        } else {
            print("Scene depth not supported")
        }
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func setFrameRate(_ frameRate: Int) {
        self.frameRate = frameRate
    }
    
    func resumeStream() {
        runSession()
        isProcessingCapturedResult = false
    }
    
    func stopStream() {
        session.pause()
        isProcessingCapturedResult = false
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let camera = frame.camera
        
        let transform = camera.transform
        let intrinsics = camera.intrinsics
        let additionalPayload = getAdditionalPayload(cameraTransform: transform, intrinsics: intrinsics)
        
        if !checkFrameWithinFrameRate(frame: frame) {
            return
        }
        
        let cameraImage: CIImage = orientAndFixCameraFrame(frame.capturedImage)
        var depthImage: CIImage? = nil
        if let depthMap = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap {
            depthImage = orientAndFixDepthFrame(depthMap)
        } else {
            print("Depth map not available")
        }
        DispatchQueue.main.async {
            if self.isProcessingCapturedResult {
                return
            }
            let previousImage = self.sharedImageData?.cameraImage
            self.sharedImageData?.cameraImage = cameraImage // UIImage(cgImage: cameraImage, scale: 1.0, orientation: .right)
            self.sharedImageData?.depthImage = depthImage
            
            self.cameraUIImage = UIImage(ciImage: cameraImage)
            if depthImage != nil { self.depthUIImage = UIImage(ciImage: depthImage!) }
            
            self.segmentationPipeline?.processRequest(with: cameraImage, previousImage: previousImage,
                                                      deviceOrientation: self.deviceOrientation,
                                                      additionalPayload: additionalPayload
            )
            
            if self.dataAvailable == false {
                self.dataAvailable = true
            }
        }
    }
    
    private func getAdditionalPayload(cameraTransform: simd_float4x4, intrinsics: simd_float3x3) -> [String: Any] {
        var additionalPayload: [String: Any] = [:]
        additionalPayload[ARContentViewConstants.Payload.cameraTransform] = cameraTransform
        additionalPayload[ARContentViewConstants.Payload.cameraIntrinsics] = intrinsics
        return additionalPayload
    }
    
    func checkFrameWithinFrameRate(frame: ARFrame) -> Bool {
        let currentTime = frame.timestamp
        let withinFrameRate = currentTime - lastFrameTime >= (1.0 / Double(frameRate))
        if withinFrameRate {
            lastFrameTime = currentTime
        }
        return withinFrameRate
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
            kCVPixelBufferWidthKey as String: Constants.ClassConstants.inputSize.width,
            kCVPixelBufferHeightKey as String: Constants.ClassConstants.inputSize.height,
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
            throw CameraManagerError.pixelBufferPoolCreationFailed
        }
        cameraColorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Set up the pixel buffer pool for depth images
        let depthPixelBufferPoolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 5
        ]
        let depthPixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_DepthFloat32,
            kCVPixelBufferWidthKey as String: Constants.ClassConstants.inputSize.width,
            kCVPixelBufferHeightKey as String: Constants.ClassConstants.inputSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let depthStatus = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            depthPixelBufferPoolAttributes as CFDictionary,
            depthPixelBufferAttributes as CFDictionary,
            &depthPixelBufferPool
        )
        guard depthStatus == kCVReturnSuccess else {
            throw CameraManagerError.pixelBufferPoolCreationFailed
        }
        depthColorSpace = nil
    }
    
    func orientAndFixCameraFrame(_ frame: CVPixelBuffer) -> CIImage {
        let croppedSize: CGSize = CGSize(
            width: Constants.ClassConstants.inputSize.width,
            height: Constants.ClassConstants.inputSize.height
        )
        var cameraImage = CIImage(cvPixelBuffer: frame)
        cameraImage = resizeAspectAndFill(cameraImage, to: croppedSize)
        cameraImage = cameraImage.oriented(
            CameraOrientation.getCGImageOrientationForBackCamera(currentDeviceOrientation: self.deviceOrientation)
        )
        let renderedCameraPixelBuffer = renderCIImageToPixelBuffer(
            cameraImage,
            size: croppedSize,
            pixelBufferPool: cameraPixelBufferPool!,
            colorSpace: cameraColorSpace
        )
        return renderedCameraPixelBuffer != nil ? CIImage(cvPixelBuffer: renderedCameraPixelBuffer!) : cameraImage
    }
    
    func orientAndFixDepthFrame(_ frame: CVPixelBuffer) -> CIImage {
        let croppedSize: CGSize = CGSize(
            width: Constants.ClassConstants.inputSize.width,
            height: Constants.ClassConstants.inputSize.height
        )
        
        var depthImage = CIImage(cvPixelBuffer: frame)
        depthImage = resizeAspectAndFill(depthImage, to: croppedSize)
        depthImage = depthImage.oriented(
            CameraOrientation.getCGImageOrientationForBackCamera(currentDeviceOrientation: self.deviceOrientation)
        )
        let depthPixelBuffer = renderCIImageToPixelBuffer(
            depthImage,
            size: croppedSize,
            pixelBufferPool: depthPixelBufferPool!,
            colorSpace: depthColorSpace
        )
        return depthPixelBuffer != nil ? CIImage(cvPixelBuffer: depthPixelBuffer!) : depthImage
    }
    
    private func resizeAspectAndFill(_ image: CIImage, to size: CGSize) -> CIImage {
        let sourceAspect = image.extent.width / image.extent.height
        let destAspect = size.width / size.height
        
        var transform: CGAffineTransform = .identity
        if sourceAspect > destAspect {
            let scale = size.height / image.extent.height
            let newWidth = image.extent.width * scale
            let xOffset = (size.width - newWidth) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: xOffset / scale, y: 0)
        } else {
            let scale = size.width / image.extent.width
            let newHeight = image.extent.height * scale
            let yOffset = (size.height - newHeight) / 2
            transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: 0, y: yOffset / scale)
        }
        let newImage = image.transformed(by: transform)
        let croppedImage = newImage.cropped(to: CGRect(origin: .zero, size: size))
        return croppedImage
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
