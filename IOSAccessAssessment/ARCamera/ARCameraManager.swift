//  ARCameraManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/22/25.
//

import ARKit
import RealityKit
import Combine
import simd

enum ARCameraManagerError: Error, LocalizedError {
    case sessionConfigurationFailed
    case pixelBufferPoolCreationFailed
    case cameraImageRenderingFailed
    case segmentationNotConfigured
    case segmentationProcessingFailed
    case cameraImageResultsUnavailable
    case segmentationImagePixelBufferUnavailable
    
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
        case .cameraImageResultsUnavailable:
            return "Camera image not processed."
        case .segmentationImagePixelBufferUnavailable:
            return "Segmentation image not backed by a pixel buffer."
        }
    }
}

enum ARCameraManagerConstants {
    enum MeshResults {
        static let meshAnchorEntityPlaceholderName = "ARCameraManager_MeshAnchorEntity"
    }
    
    enum Payload {
        static let isCameraStopped = "isStopped"
        static let cameraTransform = "cameraTransform"
        static let cameraIntrinsics = "cameraIntrinsics"
        static let originalImageSize = "originalImageSize"
    }
}

struct ARCameraImageResults {
    let cameraImage: CIImage
    var depthImage: CIImage? = nil
    var confidenceImage: CIImage? = nil
    
    let segmentationLabelImage: CIImage
    let segmentedIndices: [Int]
    let detectedObjectMap: [UUID: DetectedObject]
    let cameraTransform: simd_float4x4
    let cameraIntrinsics: simd_float3x3
    let interfaceOrientation: UIInterfaceOrientation
    let originalImageSize: CGSize
    
    var segmentationColorImage: CIImage? = nil
    var segmentationBoundingFrameImage: CIImage? = nil
    
    // TODO: Have some kind of type-safe payload for additional data to make it easier to use
    var additionalPayload: [String: Any] = [:] // This can be used to pass additional data if needed
    
    init(
        cameraImage: CIImage, depthImage: CIImage? = nil, confidenceImage: CIImage? = nil,
        segmentationLabelImage: CIImage, segmentedIndices: [Int],
        detectedObjectMap: [UUID: DetectedObject],
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        interfaceOrientation: UIInterfaceOrientation, originalImageSize: CGSize,
        segmentationColorImage: CIImage? = nil, segmentationBoundingFrameImage: CIImage? = nil,
        additionalPayload: [String: Any] = [:]
    ) {
        self.cameraImage = cameraImage
        self.depthImage = depthImage
        self.confidenceImage = confidenceImage
        
        self.segmentationLabelImage = segmentationLabelImage
        self.segmentedIndices = segmentedIndices
        self.detectedObjectMap = detectedObjectMap
        self.cameraTransform = cameraTransform
        self.cameraIntrinsics = cameraIntrinsics
        self.interfaceOrientation = interfaceOrientation
        self.originalImageSize = originalImageSize
        
        self.segmentationColorImage = segmentationColorImage
        self.segmentationBoundingFrameImage = segmentationBoundingFrameImage
        self.additionalPayload = additionalPayload
    }
}

struct ARCameraMeshResults {
    var meshAnchors: [ARMeshAnchor] = []
    
    let anchorEntity: AnchorEntity
    var classModelEntities: [Int: ModelEntity] = [:]
    var classColors: [Int: UIColor] = [:]
    var lastUpdated: TimeInterval
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
    var imageResolution: CGSize = .zero
    var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    var frameRate: Int = 15
    var lastFrameTime: TimeInterval = 0
    
    // Properties for processing camera and depth frames
    var ciContext = CIContext(options: nil)
    // Pixel buffer pools for rendering camera frames to fixed size as segmentation model input (pre-defined size)
    var cameraPixelBufferPool: CVPixelBufferPool? = nil
    var cameraColorSpace: CGColorSpace? = nil
//    var depthPixelBufferPool: CVPixelBufferPool? = nil
//    var depthColorSpace: CGColorSpace? = nil
    // Pixel buffer pools for backing segmentation images to pixel buffer of camera frame size
    var segmentationPixelBufferPool: CVPixelBufferPool? = nil
    var segmentationColorSpace: CGColorSpace? = nil
    
    @Published var cameraImageResults: ARCameraImageResults?
    @Published var cameraMeshResults: ARCameraMeshResults?
    
    override init() {
        super.init()
    }
    
    func configure(segmentationPipeline: SegmentationARPipeline) throws {
        self.segmentationPipeline = segmentationPipeline
        
        do {
            try setUpPreAllocatedPixelBufferPools(size: Constants.SelectedSegmentationConfig.inputSize)
        } catch let error as ARCameraManagerError {
            throw error
        }
    }
    
    func setVideoFormatImageResolution(_ imageResolution: CGSize) {
        self.imageResolution = imageResolution
        do {
            try setupSegmentationPixelBufferPool(size: imageResolution)
        } catch {
            print("Error setting up segmentation pixel buffer pool: \(error.localizedDescription)")
        }
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientation) {
        self.interfaceOrientation = orientation
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
        
        let depthBuffer = frame.smoothedSceneDepth?.depthMap ?? frame.sceneDepth?.depthMap
        let depthConfidenceBuffer = frame.smoothedSceneDepth?.confidenceMap ?? frame.sceneDepth?.confidenceMap
        
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer)
        let depthImage: CIImage? = depthBuffer != nil ? CIImage(cvPixelBuffer: depthBuffer!) : nil
        let confidenceImage: CIImage? = depthConfidenceBuffer != nil ? CIImage(cvPixelBuffer: depthConfidenceBuffer!) : nil
        
        // Perform async processing in a Task. Read the consumer-provided orientation on the MainActor
        Task {
             do {
                 let cameraImageResults = try await processCameraImage(
                     image: cameraImage, interfaceOrientation: interfaceOrientation, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
                 )
                 guard let cameraImageResults else {
                     throw ARCameraManagerError.segmentationProcessingFailed
                 }
                 await MainActor.run {
                     self.cameraImageResults = {
                        var results = cameraImageResults
                        results.depthImage = depthImage
                        results.confidenceImage = confidenceImage
                        return results
                     }()
                     
                     self.outputConsumer?.cameraManager(
                         self, segmentationImage: cameraImageResults.segmentationColorImage,
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
        // TODO: Throttle with frame rate if needed
        Task {
            do {
                try await processMeshAnchors(anchors)
            } catch {
                print("Error processing anchors: \(error.localizedDescription)")
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard isConfigured else {
            return
        }
        // TODO: Throttle with frame rate if needed
        Task {
            do {
                try await processMeshAnchors(anchors)
            } catch {
                print("Error processing anchors: \(error.localizedDescription)")
            }
        }
    }
    
    func setFrameRate(_ frameRate: Int) {
        self.frameRate = frameRate
    }
}

// Functions to handle the image processing pipeline
extension ARCameraManager {
    private func processCameraImage(
        image: CIImage, interfaceOrientation: UIInterfaceOrientation,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) async throws -> ARCameraImageResults? {
        guard let cameraPixelBufferPool = cameraPixelBufferPool,
              let segmentationPixelBufferPool = segmentationPixelBufferPool else {
            throw ARCameraManagerError.pixelBufferPoolCreationFailed
        }
        guard let segmentationPipeline = segmentationPipeline else {
            throw ARCameraManagerError.segmentationNotConfigured
        }
        let originalSize: CGSize = image.extent.size
        let croppedSize = SegmentationConfig.mapillaryCustom11Config.inputSize
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: interfaceOrientation
        )
        let inverseOrientation = imageOrientation.inverted()
        
        let orientedImage = image.oriented(imageOrientation)
        let inputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        let renderedCameraPixelBuffer = try renderCIImageToPixelBuffer(
            inputImage,
            size: croppedSize,
            pixelBufferPool: cameraPixelBufferPool,
            colorSpace: cameraColorSpace
        )
        let renderedCameraImage = CIImage(cvPixelBuffer: renderedCameraPixelBuffer)
        
        let segmentationResults: SegmentationARPipelineResults = try await segmentationPipeline.processRequest(with: renderedCameraImage)
        
        var segmentationImage = segmentationResults.segmentationImage
        segmentationImage = segmentationImage.oriented(inverseOrientation)
        segmentationImage = CenterCropTransformUtils.revertCenterCropAspectFit(segmentationImage, from: originalSize)
        segmentationImage = try backCIImageToPixelBuffer(
            segmentationImage,
            pixelBufferPool: segmentationPixelBufferPool,
            colorSpace: segmentationColorSpace
        )
        
        var segmentationColorCIImage = segmentationResults.segmentationColorImage
        segmentationColorCIImage = segmentationColorCIImage.oriented(inverseOrientation)
        segmentationColorCIImage = CenterCropTransformUtils.revertCenterCropAspectFit(
            segmentationColorCIImage, from: originalSize
        )
        segmentationColorCIImage = segmentationColorCIImage.oriented(imageOrientation)
        let segmentationColorCGImage = ciContext.createCGImage(segmentationColorCIImage, from: segmentationColorCIImage.extent)
        var segmentationColorImage: CIImage? = nil
        if let segmentationColorCGImage = segmentationColorCGImage {
            segmentationColorImage = CIImage(cgImage: segmentationColorCGImage)
        }
        
        let detectedObjectMap = alignDetectedObjects(
            segmentationResults.detectedObjectMap,
            orientation: imageOrientation, imageSize: croppedSize, originalSize: originalSize
        )
        
        // Create segmentation frame
        let segmentationBoundingFrameImage = getSegmentationBoundingFrame(
            imageSize: originalSize, frameSize: croppedSize, orientation: imageOrientation
        )
        let additionalPayload = getAdditionalPayload(
            cameraTransform: cameraTransform, intrinsics: cameraIntrinsics, originalCameraImageSize: originalSize
        )
        
        let cameraImageResults = ARCameraImageResults(
            cameraImage: image,
            segmentationLabelImage: segmentationImage,
            segmentedIndices: segmentationResults.segmentedIndices,
            detectedObjectMap: detectedObjectMap,
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics,
            interfaceOrientation: interfaceOrientation,
            originalImageSize: originalSize,
            segmentationColorImage: segmentationColorImage,
            segmentationBoundingFrameImage: segmentationBoundingFrameImage,
            additionalPayload: additionalPayload
        )
        return cameraImageResults
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
            let alignedObject = object
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

// Functions to handle the mesh processing pipeline
extension ARCameraManager {
    private func processMeshAnchors(_ anchors: [ARAnchor]) async throws {
        guard let cameraImageResults = cameraImageResults else {
            throw ARCameraManagerError.cameraImageResultsUnavailable
        }
        let segmentationLabelImage = cameraImageResults.segmentationLabelImage
        guard let segmentationPixelBuffer = segmentationLabelImage.pixelBuffer else {
            throw ARCameraManagerError.segmentationImagePixelBufferUnavailable
        }
        let cameraTransform = cameraImageResults.cameraTransform
        let cameraIntrinsics = cameraImageResults.cameraIntrinsics
        
        
        
    }
    
    private func initializeMeshResultsIfNeeded() {
        guard cameraMeshResults == nil else {
            return
        }
        let anchorEntity = AnchorEntity(world: .zero)
        
    }
}

// Functions to orient and fix the camera and depth frames
extension ARCameraManager {
    private func setUpPreAllocatedPixelBufferPools(size: CGSize) throws {
        // Set up the pixel buffer pool for future flattening of camera images
        let cameraPixelBufferPoolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 5
        ]
        let cameraPixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
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
        pixelBufferPool: CVPixelBufferPool, colorSpace: CGColorSpace? = nil
    ) throws -> CVPixelBuffer {
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBufferOut)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
            throw ARCameraManagerError.cameraImageRenderingFailed
        }
        
        ciContext.render(image, to: pixelBuffer, bounds: CGRect(origin: .zero, size: size), colorSpace: colorSpace)
        return pixelBuffer
    }
    
    private func setupSegmentationPixelBufferPool(size: CGSize) throws {
        // Set up the pixel buffer pool for future flattening of segmentation images
        let segmentationPixelBufferPoolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 5
        ]
        let segmentationPixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_OneComponent8,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let segmentationStatus = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            segmentationPixelBufferPoolAttributes as CFDictionary,
            segmentationPixelBufferAttributes as CFDictionary,
            &segmentationPixelBufferPool
        )
        guard segmentationStatus == kCVReturnSuccess else {
            throw ARCameraManagerError.pixelBufferPoolCreationFailed
        }
        segmentationColorSpace = CGColorSpaceCreateDeviceGray()
    }
    
    private func backCIImageToPixelBuffer(
        _ image: CIImage,
        pixelBufferPool: CVPixelBufferPool, colorSpace: CGColorSpace? = nil
    ) throws -> CIImage {
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBufferOut)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
            throw ARCameraManagerError.cameraImageRenderingFailed
        }
        // Render the CIImage to the pixel buffer
        ciContext.render(image, to: pixelBuffer, bounds: image.extent, colorSpace: colorSpace)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciImage
    }
}
