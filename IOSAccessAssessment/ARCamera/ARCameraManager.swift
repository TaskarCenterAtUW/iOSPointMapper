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
    case cameraImageRenderingFailed
    case segmentationNotConfigured
    case segmentationProcessingFailed
    
    var errorDescription: String? {
        switch self {
        case .sessionConfigurationFailed:
            return "AR session configuration failed."
        case .pixelBufferPoolCreationFailed:
            return "Failed to create pixel buffer pool."
        case .cameraImageRenderingFailed:
            return "Failed to render camera image."
        case .segmentationNotConfigured:
            return "Segmentation pipeline not configured."
        case .segmentationProcessingFailed:
            return "Segmentation processing failed."
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

struct ARCameraManagerCameraImageResults {
    var imageData: ImageData
    var cameraAspectMultiplier: CGFloat
    var segmentationColorImage: CIImage
    var segmentationBoundingFrameImage: CIImage? = nil
    
    // TODO: Have some kind of type-safe payload for additional data to make it easier to use
    var additionalPayload: [String: Any] = [:] // This can be used to pass additional data if needed
    
    init(imageData: ImageData,
         cameraAspectMultiplier: CGFloat,
         segmentationColorImage: CIImage, segmentationBoundingFrameImage: CIImage? = nil,
         additionalPayload: [String: Any] = [:]) {
        self.imageData = imageData
        self.cameraAspectMultiplier = cameraAspectMultiplier
        self.segmentationColorImage = segmentationColorImage
        self.segmentationBoundingFrameImage = segmentationBoundingFrameImage
        self.additionalPayload = additionalPayload
    }
}

/**
    An object that manages the AR session and processes camera frames for segmentation using a provided segmentation pipeline.
 
    Is configured through a two-step process to make initialization in SwiftUI easier.
    - First, initialize with local properties (e.g. pixel buffer pools).
    - Accept configuration of the SegmentationARPipeline through a separate `configure()` method.
 */
final class ARCameraManager: NSObject, ObservableObject, ARSessionCameraProcessingDelegate {
    var isConfigured: Bool {
        return segmentationPipeline != nil
    }
    var segmentationPipeline: SegmentationARPipeline? = nil
    
    // Consumer that will receive processed overlays (weak to avoid retain cycles)
    weak var outputConsumer: ARSessionCameraProcessingOutputConsumer? = nil
    
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
    
    @Published var cameraImageResults: ARCameraManagerCameraImageResults?
    
    override init() {
        super.init()
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.deviceOrientation = UIDevice.current.orientation
        }.store(in: &cancellables)
    }
    
    func configure(segmentationPipeline: SegmentationARPipeline) throws {
        self.segmentationPipeline = segmentationPipeline
        
        do {
            try setUpPixelBufferPools()
        } catch let error as ARCameraManagerError {
            throw error
        }
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isConfigured else {
            return
        }
        guard checkFrameWithinFrameRate(frame: frame) else {
            return
        }
        
        let pixelBuffer = frame.capturedImage
        let cameraTransform = frame.camera.transform
        let cameraIntrinsics = frame.camera.intrinsics
        
//        let depthBuffer = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap
//        let depthConfidenceBuffer = frame.smoothedSceneDepth?.confidenceMap ?? frame.sceneDepth?.confidenceMap
        
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        Task {
            do {
                let cameraImageResults = try await processCameraImage(
                    image: cameraImage, deviceOrientation: deviceOrientation, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
                )
                guard let cameraImageResults else {
                    throw ARCameraManagerError.segmentationProcessingFailed
                }
                await MainActor.run {
                    self.cameraImageResults = cameraImageResults
                    
                    self.outputConsumer?.cameraManager(
                        self, cameraAspectMultipler: cameraImageResults.cameraAspectMultiplier,
                        segmentationImage: cameraImageResults.segmentationColorImage,
                        segmentationBoundingFrameImage: cameraImageResults.segmentationBoundingFrameImage,
                        for: frame
                    )
                }
            } catch {
                print("Error processing camera image: \(error.localizedDescription)")
            }
        }
    }
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard isConfigured else {
            return
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard isConfigured else {
            return
        }
    }
    
    private func processCameraImage(
        image: CIImage, deviceOrientation: UIDeviceOrientation,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) async throws -> ARCameraManagerCameraImageResults? {
        guard let segmentationPipeline = segmentationPipeline else {
            throw ARCameraManagerError.segmentationNotConfigured
        }
        let originalSize: CGSize = CGSize(
            width: image.extent.width,
            height: image.extent.height
        )
        let croppedSize = SegmentationConfig.cocoCustom11Config.inputSize
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForBackCamera(
            currentDeviceOrientation: deviceOrientation
        )
        
        let orientedImage = image.oriented(imageOrientation)
        let inputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        let renderedCameraPixelBuffer = renderCIImageToPixelBuffer(
            inputImage,
            size: croppedSize,
            pixelBufferPool: cameraPixelBufferPool!,
            colorSpace: cameraColorSpace
        )
        guard let renderedCameraPixelBufferUnwrapped = renderedCameraPixelBuffer else {
            throw ARCameraManagerError.cameraImageRenderingFailed
        }
        let renderedCameraImage = CIImage(cvPixelBuffer: renderedCameraPixelBufferUnwrapped)
        
        let segmentationResults: SegmentationARPipelineResults = try await segmentationPipeline.processRequest(with: renderedCameraImage)
        
        var segmentationImage = segmentationResults.segmentationImage
        var segmentationColorImage = segmentationResults.segmentationColorImage
        
        let inverseOrientation = imageOrientation.inverted()
        
        segmentationImage = segmentationImage.oriented(inverseOrientation)
        segmentationImage = CenterCropTransformUtils.revertCenterCropAspectFit(segmentationImage, from: originalSize)
        
        segmentationColorImage = segmentationColorImage.oriented(inverseOrientation)
        segmentationColorImage = CenterCropTransformUtils.revertCenterCropAspectFit(
            segmentationColorImage, from: originalSize
        )
        segmentationColorImage = segmentationColorImage.oriented(imageOrientation)
        guard let segmentationColorCGImage = ciContext.createCGImage(
            segmentationColorImage, from: segmentationColorImage.extent) else {
            throw ARCameraManagerError.cameraImageRenderingFailed
        }
        segmentationColorImage = CIImage(cgImage: segmentationColorCGImage)
        
        let detectedObjectMap = alignDetectedObjects(
            segmentationResults.detectedObjectMap,
            orientation: imageOrientation, imageSize: croppedSize, originalSize: originalSize
        )
        
        let cameraAspectMultiplier = orientedImage.extent.width / orientedImage.extent.height
        // Create segmentation frame
        let segmentationBoundingFrameImage = getSegmentationBoundingFrame(
            imageSize: originalSize, frameSize: croppedSize, orientation: imageOrientation
        )
        let additionalPayload = getAdditionalPayload(
            cameraTransform: cameraTransform, intrinsics: cameraIntrinsics, originalCameraImageSize: originalSize
        )
        
        let cameraImageData = ImageData(
            segmentationLabelImage: segmentationImage,
            segmentedIndices: segmentationResults.segmentedIndices,
            detectedObjectMap: detectedObjectMap,
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics,
            deviceOrientation: deviceOrientation,
            originalImageSize: originalSize
        )
        let cameraImageResults = ARCameraManagerCameraImageResults(
            imageData: cameraImageData,
            cameraAspectMultiplier: cameraAspectMultiplier,
            segmentationColorImage: segmentationColorImage,
            segmentationBoundingFrameImage: segmentationBoundingFrameImage,
            additionalPayload: additionalPayload
        )
        return cameraImageResults
    }
    
    func setFrameRate(_ frameRate: Int) {
        self.frameRate = frameRate
    }
    
    private func checkFrameWithinFrameRate(frame: ARFrame) -> Bool {
        let currentTime = frame.timestamp
        let withinFrameRate = currentTime - lastFrameTime >= (1.0 / Double(frameRate))
        if withinFrameRate {
            lastFrameTime = currentTime
        }
        return withinFrameRate
    }
    
    private func alignDetectedObjects(
        _ detectedObjectMap: [UUID: DetectedObject],
        orientation: CGImagePropertyOrientation, imageSize: CGSize, originalSize: CGSize
    ) -> [UUID: DetectedObject] {
        let orientationTransform = orientation.getNormalizedToUpTransform().inverted()
        // To revert the center-cropping effect to map back to original image size
        let revertTransform = CenterCropTransformUtils.revertCenterCropAspectFitNormalizedTransform(
            imageSize: imageSize, from: originalSize)
        let alignTransform = orientationTransform.concatenating(revertTransform)
        
        let alignedObjectMap: [UUID: DetectedObject] = detectedObjectMap.mapValues { object in
            var alignedObject = object
            alignedObject.centroid = object.centroid.applying(alignTransform)
            alignedObject.boundingBox = object.boundingBox.applying(alignTransform)
            alignedObject.normalizedPoints = object.normalizedPoints.map { point_simd in
                return CGPoint(x: CGFloat(point_simd.x), y: CGFloat(point_simd.y))
            }.map { point in
                return point.applying(alignTransform)
            }.map { point in
                return SIMD2<Float>(x: Float(point.x), y: Float(point.y))
            }
            return alignedObject
        }
        
        return alignedObjectMap
    }
    
    private func getSegmentationBoundingFrame(
        imageSize: CGSize, frameSize: CGSize, orientation: CGImagePropertyOrientation
    ) -> CIImage? {
        guard let segmentationFrameCGImage = FrameRasterizer.create(imageSize: imageSize, frameSize: frameSize) else {
            return nil
        }
        var segmentationFrameImage = CIImage(cgImage: segmentationFrameCGImage)
        segmentationFrameImage = segmentationFrameImage.oriented(orientation)
        guard let segmentationFrameOrientedCGImage = ciContext.createCGImage(
            segmentationFrameImage, from: segmentationFrameImage.extent) else {
            return nil
        }
        segmentationFrameImage = CIImage(cgImage: segmentationFrameOrientedCGImage)
        return segmentationFrameImage
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
