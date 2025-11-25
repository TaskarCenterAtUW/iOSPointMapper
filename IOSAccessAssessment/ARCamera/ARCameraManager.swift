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
    case segmentationMeshNotConfigured
    case segmentationProcessingFailed
    case cameraImageResultsUnavailable
    case segmentationImagePixelBufferUnavailable
    case metalDeviceUnavailable
    case meshSnapshotGeneratorUnavailable
    case meshSnapshotProcessingFailed
    case anchorEntityNotCreated
    case finalSessionNotConfigured
    case finalSessionMeshUnavailable
    case finalSessionNoSegmentationClass
    case finalSessionNoSegmentationMesh
    
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
        case .segmentationMeshNotConfigured:
            return "Segmentation mesh pipeline not configured."
        case .segmentationProcessingFailed:
            return "Segmentation processing failed."
        case .cameraImageResultsUnavailable:
            return "Camera image not processed."
        case .segmentationImagePixelBufferUnavailable:
            return "Segmentation image not backed by a pixel buffer."
        case .metalDeviceUnavailable:
            return "Metal device unavailable."
        case .meshSnapshotGeneratorUnavailable:
            return "Mesh snapshot generator unavailable."
        case .meshSnapshotProcessingFailed:
            return "Mesh snapshot processing failed."
        case .anchorEntityNotCreated:
            return "Anchor Entity has not been created."
        case .finalSessionNotConfigured:
            return "Final session update not configured."
        case .finalSessionMeshUnavailable:
            return "Final session mesh data unavailable."
        case .finalSessionNoSegmentationClass:
            return "No segmentation class available in final session."
        case .finalSessionNoSegmentationMesh:
            return "No segmentation mesh available in final session."
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
    let segmentedClasses: [AccessibilityFeatureClass]
    let detectedObjectMap: [UUID: DetectedAccessibilityFeature]
    let cameraTransform: simd_float4x4
    let cameraIntrinsics: simd_float3x3
    let interfaceOrientation: UIInterfaceOrientation
    let originalImageSize: CGSize
    
    var segmentationColorImage: CIImage? = nil
    var segmentationBoundingFrameImage: CIImage? = nil
    
    init(
        cameraImage: CIImage, depthImage: CIImage? = nil, confidenceImage: CIImage? = nil,
        segmentationLabelImage: CIImage, segmentedClasses: [AccessibilityFeatureClass],
        detectedObjectMap: [UUID: DetectedAccessibilityFeature],
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        interfaceOrientation: UIInterfaceOrientation,
        originalImageSize: CGSize,
        segmentationColorImage: CIImage? = nil, segmentationBoundingFrameImage: CIImage? = nil
    ) {
        self.cameraImage = cameraImage
        self.depthImage = depthImage
        self.confidenceImage = confidenceImage
        
        self.segmentationLabelImage = segmentationLabelImage
        self.segmentedClasses = segmentedClasses
        self.detectedObjectMap = detectedObjectMap
        self.cameraTransform = cameraTransform
        self.cameraIntrinsics = cameraIntrinsics
        
        self.interfaceOrientation = interfaceOrientation
        
        self.originalImageSize = originalImageSize
        
        self.segmentationColorImage = segmentationColorImage
        self.segmentationBoundingFrameImage = segmentationBoundingFrameImage
    }
}

struct ARCameraMeshResults {
    let meshGPUSnapshot: MeshGPUSnapshot
    
    let meshAnchors: [ARMeshAnchor]
    let segmentationLabelImage: CIImage
    let cameraTransform: simd_float4x4
    let cameraIntrinsics: simd_float3x3
    
    let lastUpdated: TimeInterval
    
    init(
        meshGPUSnapshot: MeshGPUSnapshot,
        meshAnchors: [ARMeshAnchor] = [],
        segmentationLabelImage: CIImage,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        lastUpdated: TimeInterval,
    ) {
        self.meshGPUSnapshot = meshGPUSnapshot
        self.meshAnchors = meshAnchors
        self.segmentationLabelImage = segmentationLabelImage
        self.cameraTransform = cameraTransform
        self.cameraIntrinsics = cameraIntrinsics
        self.lastUpdated = lastUpdated
    }
}

/**
    A struct to cache camera properties for optimization.
 */
struct ARCameraCache {
    var cameraImageSize: CGSize?
    var interfaceOrientation: UIInterfaceOrientation
    
    init(cameraImageSize: CGSize? = nil, interfaceOrientation: UIInterfaceOrientation = .portrait) {
        self.cameraImageSize = cameraImageSize
        self.interfaceOrientation = interfaceOrientation
    }
}

/**
    An object that manages the AR session and processes camera frames for segmentation using a provided segmentation pipeline.
 
    Is configured through a two-step process to make initialization in SwiftUI easier.
    - First, initialize with local properties (e.g. pixel buffer pools).
    - Accept configuration of the SegmentationARPipeline through a separate `configure()` method.
 */
final class ARCameraManager: NSObject, ObservableObject, ARSessionCameraProcessingDelegate {
    var selectedClasses: [AccessibilityFeatureClass] = []
    var segmentationPipeline: SegmentationARPipeline? = nil
    var meshGPUSnapshotGenerator: MeshGPUSnapshotGenerator? = nil
    var capturedMeshSnapshotGenerator: CapturedMeshSnapshotGenerator? = nil
    
    var metalContext: MetalContext? = nil
    
    // Consumer that will receive processed overlays (weak to avoid retain cycles)
    weak var outputConsumer: ARSessionCameraProcessingOutputConsumer? = nil
    var imageResolution: CGSize = .zero
    @Published var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    var frameRate: Int = 15
    var lastFrameTime: TimeInterval = 0
    var meshFrameRate: Int = 15
    var lastMeshFrameTime: TimeInterval = 0
    
    // Contexts depending on type of color space processing required
    let colorContext = CIContext(options: nil)
    let rawContext = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    // Properties for processing camera and depth frames
    // Pixel buffer pools for rendering camera frames to fixed size as segmentation model input (pre-defined size)
    var cameraCroppedPixelBufferPool: CVPixelBufferPool? = nil
    var cameraColorSpace: CGColorSpace? = CGColorSpaceCreateDeviceRGB()
    var cameraPixelFormatType: OSType = kCVPixelFormatType_32BGRA
    var segmentationBoundingFrameColorSpace: CGColorSpace? = CGColorSpaceCreateDeviceRGB()
//    var depthPixelBufferPool: CVPixelBufferPool? = nil
//    var depthColorSpace: CGColorSpace? = nil
    // Pixel buffer pools for backing segmentation images to pixel buffer of camera frame size
    var segmentationMaskPixelBufferPool: CVPixelBufferPool? = nil
    var segmentationMaskPixelFormatType: OSType = kCVPixelFormatType_OneComponent8
    /// TODO: While the segmentation color space is hard-coded for now, add it as part of the AccessibilityFeatureConfig later.
    var segmentationMaskColorSpace: CGColorSpace? = nil
    var segmentationColorPixelFormatType: OSType = kCVPixelFormatType_32BGRA
    var segmentationColorColorSpace: CGColorSpace? = CGColorSpaceCreateDeviceRGB()
    
    @Published var isConfigured: Bool = false
    
    // Latest processed results
    var cameraImageResults: ARCameraImageResults?
    var cameraMeshResults: ARCameraMeshResults?
    var cameraCache: ARCameraCache = ARCameraCache()
    
    override init() {
        super.init()
    }
    
    func configure(
        selectedClasses: [AccessibilityFeatureClass], segmentationPipeline: SegmentationARPipeline,
        metalContext: MetalContext?
    ) throws {
        self.selectedClasses = selectedClasses
        self.segmentationPipeline = segmentationPipeline
        
        guard let metalContext = metalContext else {
            throw ARCameraManagerError.metalDeviceUnavailable
        }
        self.metalContext = metalContext
        self.meshGPUSnapshotGenerator = MeshGPUSnapshotGenerator(device: metalContext.device)
        try setUpPreAllocatedPixelBufferPools(size: Constants.SelectedAccessibilityFeatureConfig.inputSize)
        self.isConfigured = true
        
        Task {
            await MainActor.run {
                self.capturedMeshSnapshotGenerator = CapturedMeshSnapshotGenerator()
            }
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
    
    func setFrameRate(_ frameRate: Int) {
        self.frameRate = frameRate
    }
    
    func setMeshFrameRate(_ meshFrameRate: Int) {
        self.meshFrameRate = meshFrameRate
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isConfigured else {
            return
        }
        guard checkFrameWithinFrameRate(frame: frame) else {
            return
        }
        guard let metalContext = metalContext else {
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
        
        /// Perform async processing in a Task. Read the consumer-provided orientation on the MainActor
        Task {
             do {
                 let cameraImageResults = try await processCameraImage(
                     image: cameraImage, interfaceOrientation: interfaceOrientation, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
                 )
                 await MainActor.run {
                     var results = cameraImageResults
                     results.depthImage = depthImage
                     results.confidenceImage = confidenceImage
                     self.cameraImageResults = results
                     self.outputConsumer?.cameraOutputImage(
                         self, metalContext: metalContext,
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
        guard checkMeshWithinMeshFrameRate(currentTime: Date().timeIntervalSince1970) else {
            return
        }
        guard let metalContext = metalContext else {
            return
        }
        Task {
            do {
                let cameraMeshResults = try await processMeshAnchors(anchors)
                await MainActor.run {
                    self.cameraMeshResults = cameraMeshResults
                    self.outputConsumer?.cameraOutputMesh(
                        self, metalContext: metalContext,
                        meshGPUSnapshot: cameraMeshResults.meshGPUSnapshot,
                        for: anchors,
                        cameraTransform: cameraMeshResults.cameraTransform,
                        cameraIntrinsics: cameraMeshResults.cameraIntrinsics,
                        segmentationLabelImage: cameraMeshResults.segmentationLabelImage,
                        accessibilityFeatureClasses: self.selectedClasses
                    )
                }
            } catch {
                print("Error processing anchors: \(error.localizedDescription)")
            }
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard isConfigured else {
            return
        }
        guard checkMeshWithinMeshFrameRate(currentTime: Date().timeIntervalSince1970) else {
            return
        }
        guard let metalContext = metalContext else {
            return
        }
        Task {
            do {
                let cameraMeshResults = try await processMeshAnchors(anchors)
                await MainActor.run {
                    self.cameraMeshResults = cameraMeshResults
                    self.outputConsumer?.cameraOutputMesh(
                        self, metalContext: metalContext,
                        meshGPUSnapshot: cameraMeshResults.meshGPUSnapshot,
                        for: anchors,
                        cameraTransform: cameraMeshResults.cameraTransform,
                        cameraIntrinsics: cameraMeshResults.cameraIntrinsics,
                        segmentationLabelImage: cameraMeshResults.segmentationLabelImage,
                        accessibilityFeatureClasses: self.selectedClasses
                    )
                }
            } catch {
                print("Error processing anchors: \(error.localizedDescription)")
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard isConfigured else {
            return
        }
        guard checkMeshWithinMeshFrameRate(currentTime: Date().timeIntervalSince1970) else {
            return
        }
        guard let metalContext = metalContext else {
            return
        }
        Task {
            do {
                let cameraMeshResults = try await processMeshAnchors(anchors, shouldRemove: true)
                await MainActor.run {
                    self.cameraMeshResults = cameraMeshResults
                    self.outputConsumer?.cameraOutputMesh(
                        self, metalContext: metalContext,
                        meshGPUSnapshot: cameraMeshResults.meshGPUSnapshot,
                        for: anchors,
                        cameraTransform: cameraMeshResults.cameraTransform,
                        cameraIntrinsics: cameraMeshResults.cameraIntrinsics,
                        segmentationLabelImage: cameraMeshResults.segmentationLabelImage,
                        accessibilityFeatureClasses: self.selectedClasses
                    )
                }
            } catch {
                print("Error processing anchors: \(error.localizedDescription)")
            }
        }
    }
}

// Functions to handle the image processing pipeline
extension ARCameraManager {
    private func processCameraImage(
        image: CIImage, interfaceOrientation: UIInterfaceOrientation,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        highPriority: Bool = false
    ) async throws -> ARCameraImageResults {
        guard let cameraCroppedPixelBufferPool = cameraCroppedPixelBufferPool,
              let segmentationPixelBufferPool = segmentationMaskPixelBufferPool else {
            throw ARCameraManagerError.pixelBufferPoolCreationFailed
        }
        guard let segmentationPipeline = segmentationPipeline else {
            throw ARCameraManagerError.segmentationNotConfigured
        }
        let originalSize: CGSize = image.extent.size
        let croppedSize = Constants.SelectedAccessibilityFeatureConfig.inputSize
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: interfaceOrientation
        )
        let inverseOrientation = imageOrientation.inverted()
        
        let orientedImage = image.oriented(imageOrientation)
        var inputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        inputImage = try self.backCIImageWithPixelBuffer(
            inputImage, context: colorContext, pixelBufferPool: cameraCroppedPixelBufferPool, colorSpace: cameraColorSpace
        )
        
        let segmentationResults: SegmentationARPipelineResults = try await segmentationPipeline.processRequest(
            with: inputImage, highPriority: highPriority
        )
        
        var segmentationImage = segmentationResults.segmentationImage
        segmentationImage = segmentationImage.oriented(inverseOrientation)
        segmentationImage = CenterCropTransformUtils.revertCenterCropAspectFit(segmentationImage, from: originalSize)
        segmentationImage = try self.backCIImageWithPixelBuffer(
            segmentationImage, context: rawContext, pixelBufferPool: segmentationPixelBufferPool,
            colorSpace: segmentationMaskColorSpace,
        )
        
        var segmentationColorCIImage = segmentationResults.segmentationColorImage
        segmentationColorCIImage = segmentationColorCIImage.oriented(inverseOrientation)
        segmentationColorCIImage = CenterCropTransformUtils.revertCenterCropAspectFit(
            segmentationColorCIImage, from: originalSize
        )
        segmentationColorCIImage = segmentationColorCIImage.oriented(imageOrientation)
        let segmentationColorImage = try self.backCIImageWithPixelBuffer(
            segmentationColorCIImage, context: colorContext, pixelFormatType: segmentationColorPixelFormatType,
            colorSpace: segmentationColorColorSpace
        )
        
        let detectedObjectMap = alignDetectedObjects(
            segmentationResults.detectedObjectMap,
            orientation: imageOrientation, imageSize: croppedSize, originalSize: originalSize
        )
        
        // Create segmentation frame
        var segmentationBoundingFrameImage: CIImage? = nil
        if (cameraCache.cameraImageSize == nil || cameraCache.cameraImageSize?.width != originalSize.width ||
            cameraCache.cameraImageSize?.height != originalSize.height ||
            cameraCache.interfaceOrientation != interfaceOrientation
        ) {
            segmentationBoundingFrameImage = getSegmentationBoundingFrame(
                imageSize: originalSize, frameSize: croppedSize, orientation: imageOrientation
            )
            cameraCache.cameraImageSize = originalSize
            cameraCache.interfaceOrientation = interfaceOrientation
        }
        
        let cameraImageResults = ARCameraImageResults(
            cameraImage: image,
            segmentationLabelImage: segmentationImage,
            segmentedClasses: segmentationResults.segmentedClasses,
            detectedObjectMap: detectedObjectMap,
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics,
            interfaceOrientation: interfaceOrientation,
            originalImageSize: originalSize,
            segmentationColorImage: segmentationColorImage,
            segmentationBoundingFrameImage: segmentationBoundingFrameImage
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
    
    /**
    Align detected objects back to the original image coordinate system.
     */
    private func alignDetectedObjects(
        _ detectedObjectMap: [UUID: DetectedAccessibilityFeature],
        orientation: CGImagePropertyOrientation, imageSize: CGSize, originalSize: CGSize
    ) -> [UUID: DetectedAccessibilityFeature] {
        let orientationTransform = orientation.getNormalizedToUpTransform().inverted()
        // To revert the center-cropping effect to map back to original image size
        let revertTransform = CenterCropTransformUtils.revertCenterCropAspectFitNormalizedTransform(
            imageSize: imageSize, from: originalSize)
        let alignTransform = orientationTransform.concatenating(revertTransform)
        
        let alignedObjectMap: [UUID: DetectedAccessibilityFeature] = detectedObjectMap.mapValues { object in
            let centroid = object.contourDetails.centroid.applying(alignTransform)
            let boundingBox = object.contourDetails.boundingBox.applying(alignTransform)
            let normalizedPoints = object.contourDetails.normalizedPoints.map { point_simd in
                return CGPoint(x: CGFloat(point_simd.x), y: CGFloat(point_simd.y))
            }.map { point in
                return point.applying(alignTransform)
            }.map { point in
                return SIMD2<Float>(x: Float(point.x), y: Float(point.y))
            }
            return DetectedAccessibilityFeature(
                accessibilityFeatureClass: object.accessibilityFeatureClass,
                contourDetails: ContourDetails(
                    centroid: centroid,
                    boundingBox: boundingBox,
                    normalizedPoints: normalizedPoints,
                    area: object.contourDetails.area,
                    perimeter: object.contourDetails.perimeter
                )
            )
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
        guard let segmentationFrameOrientedCGImage = colorContext.createCGImage(
            segmentationFrameImage, from: segmentationFrameImage.extent) else {
            return nil
        }
        segmentationFrameImage = CIImage(cgImage: segmentationFrameOrientedCGImage)
        return segmentationFrameImage
    }
}

// Functions to handle the mesh processing pipeline
extension ARCameraManager {
    private func processMeshAnchors(_ anchors: [ARAnchor], shouldRemove: Bool = false) async throws -> ARCameraMeshResults {
        guard let meshGPUSnapshotGenerator = meshGPUSnapshotGenerator else {
            throw ARCameraManagerError.meshSnapshotGeneratorUnavailable
        }
        guard let cameraImageResults = cameraImageResults else {
            throw ARCameraManagerError.cameraImageResultsUnavailable
        }
        
        let segmentationLabelImage = cameraImageResults.segmentationLabelImage
        let backedSegmentationLabelImage = try self.backCIImageWithPixelBuffer(
            segmentationLabelImage, context: rawContext, pixelFormatType: segmentationMaskPixelFormatType,
            colorSpace: segmentationMaskColorSpace
        )
        
        let cameraTransform = cameraImageResults.cameraTransform
        let cameraIntrinsics = cameraImageResults.cameraIntrinsics
        
        // Generate mesh snapshot
        if (shouldRemove) {
            meshGPUSnapshotGenerator.removeAnchors(anchors)
        } else {
            try meshGPUSnapshotGenerator.snapshotAnchors(anchors)
        }
        guard let meshGPUSnapshot = meshGPUSnapshotGenerator.currentSnapshot else {
            throw ARCameraManagerError.meshSnapshotProcessingFailed
        }
        return ARCameraMeshResults(
            meshGPUSnapshot: meshGPUSnapshot,
            segmentationLabelImage: backedSegmentationLabelImage,
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics,
            lastUpdated: Date().timeIntervalSince1970
        )
    }
    
    private func checkMeshWithinMeshFrameRate(currentTime: TimeInterval) -> Bool {
        let withinFrameRate = currentTime - lastMeshFrameTime >= (1.0 / Double(meshFrameRate))
        if withinFrameRate {
            lastMeshFrameTime = currentTime
        }
        return withinFrameRate
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
            kCVPixelBufferPixelFormatTypeKey as String: cameraPixelFormatType,
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
            &cameraCroppedPixelBufferPool
        )
        guard cameraStatus == kCVReturnSuccess else {
            throw ARCameraManagerError.pixelBufferPoolCreationFailed
        }
    }
    
    private func setupSegmentationPixelBufferPool(size: CGSize) throws {
        // Set up the pixel buffer pool for future flattening of segmentation images
        let segmentationMaskPixelBufferPoolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 5
        ]
        let segmentationMaskPixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: segmentationMaskPixelFormatType,
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let segmentationMaskStatus = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            segmentationMaskPixelBufferPoolAttributes as CFDictionary,
            segmentationMaskPixelBufferAttributes as CFDictionary,
            &segmentationMaskPixelBufferPool
        )
        guard segmentationMaskStatus == kCVReturnSuccess else {
            throw ARCameraManagerError.pixelBufferPoolCreationFailed
        }
    }
    
    /**
    Back a CIImage with a pixel buffer of specified pixel format type and color space.
     Also serves as a way to efficiently clone a CIImage.
     */
    private func backCIImageWithPixelBuffer(
        _ ciImage: CIImage, context: CIContext,
        pixelFormatType: OSType, colorSpace: CGColorSpace? = nil,
    ) throws -> CIImage {
        let pixelBuffer = try ciImage.toPixelBuffer(context: context, pixelFormatType: pixelFormatType, colorSpace: colorSpace)
        let backedImage = CIImage(cvPixelBuffer: pixelBuffer)
        return backedImage
    }
    
    /**
    Back a CIImage with a pixel buffer from the provided pixel buffer pool and color space.
     Also serves as a way to efficiently clone a CIImage.
     */
    private func backCIImageWithPixelBuffer(
        _ ciImage: CIImage, context: CIContext,
        pixelBufferPool: CVPixelBufferPool, colorSpace: CGColorSpace? = nil,
    ) throws -> CIImage {
        let pixelBuffer = try ciImage.toPixelBuffer(context: context, pixelBufferPool: pixelBufferPool, colorSpace: colorSpace)
        let backedImage = CIImage(cvPixelBuffer: pixelBuffer)
        return backedImage
    }
}

// Functions to perform final session update
extension ARCameraManager {
    /**
    Perform any final updates to the AR session configuration that will be required by the caller.
     Throws an error if the final session update cannot be performed.
     Throws an error if the final session update returns no segmented classes or segmented mesh.
     
     Runs the Image Segmentation Pipeline with high priority to ensure that the latest frame.
     TODO: Perform the mesh snapshot processing as well.
     */
    @MainActor
    func performFinalSessionUpdateIfPossible(
    ) async throws -> any (CaptureImageDataProtocol & CaptureMeshDataProtocol) {
        guard let capturedMeshSnapshotGenerator = self.capturedMeshSnapshotGenerator,
              let metalContext = self.metalContext,
              let meshGPUSnapshotGenerator = self.meshGPUSnapshotGenerator else {
            throw ARCameraManagerError.finalSessionNotConfigured
        }
        guard let meshGPUSnapshot = meshGPUSnapshotGenerator.currentSnapshot else {
            throw ARCameraManagerError.finalSessionMeshUnavailable
        }
        
        /// Process the latest camera image with high priority
        guard let cameraImage = self.cameraImageResults?.cameraImage,
              let depthImage = self.cameraImageResults?.depthImage,
              let cameraTransform = self.cameraImageResults?.cameraTransform,
              let cameraIntrinsics = self.cameraImageResults?.cameraIntrinsics
        else {
            throw ARCameraManagerError.cameraImageResultsUnavailable
        }
        var cameraImageResults = try await self.processCameraImage(
            image: cameraImage, interfaceOrientation: self.interfaceOrientation,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics,
            highPriority: true
        )
        guard cameraImageResults.segmentedClasses.count > 0 else {
            throw ARCameraManagerError.finalSessionNoSegmentationClass
        }
        cameraImageResults.depthImage = depthImage
        cameraImageResults.confidenceImage = self.cameraImageResults?.confidenceImage
        
        /// Process the latest mesh anchors
        let segmentationLabelImage = cameraImageResults.segmentationLabelImage
        let backedSegmentationLabelImage = try self.backCIImageWithPixelBuffer(
            segmentationLabelImage, context: rawContext, pixelFormatType: segmentationMaskPixelFormatType,
            colorSpace: segmentationMaskColorSpace
        )
        outputConsumer?.cameraOutputMesh(
            self, metalContext: metalContext,
            meshGPUSnapshot: meshGPUSnapshot,
            for: nil as [ARAnchor]?,
            cameraTransform: cameraImageResults.cameraTransform,
            cameraIntrinsics: cameraImageResults.cameraIntrinsics,
            segmentationLabelImage: backedSegmentationLabelImage,
            accessibilityFeatureClasses: self.selectedClasses
        )
        guard let cameraMeshRecordDetails = outputConsumer?.getMeshRecordDetails() else {
            throw ARCameraManagerError.finalSessionNoSegmentationMesh
        }
        guard let cameraMeshOtherDetails = cameraMeshRecordDetails.otherDetails,
              cameraMeshOtherDetails.totalVertexCount > 0 else {
            throw ARCameraManagerError.finalSessionNoSegmentationMesh
        }
        let cameraMeshRecords = cameraMeshRecordDetails.records
        
        let cameraMeshSnapshot: CapturedMeshSnapshot = capturedMeshSnapshotGenerator.snapshotSegmentationRecords(
            from: cameraMeshRecords,
            vertexStride: cameraMeshOtherDetails.vertexStride,
            vertexOffset: cameraMeshOtherDetails.vertexOffset,
            indexStride: cameraMeshOtherDetails.indexStride,
            classificationStride: cameraMeshOtherDetails.classificationStride,
            totalVertexCount: cameraMeshOtherDetails.totalVertexCount
        )
        let captureImageDataResults = CaptureImageDataResults(
            segmentationLabelImage: cameraImageResults.segmentationLabelImage,
            segmentedClasses: cameraImageResults.segmentedClasses,
            detectedObjectMap: cameraImageResults.detectedObjectMap
        )
        let captureMeshDataResults = CaptureMeshDataResults(
            segmentedMesh: cameraMeshSnapshot
        )
        
        let capturedData = CaptureAllData(
            id: UUID(),
            timestamp: Date().timeIntervalSince1970,
            cameraImage: cameraImageResults.cameraImage,
            cameraTransform: cameraImageResults.cameraTransform,
            cameraIntrinsics: cameraImageResults.cameraIntrinsics,
            interfaceOrientation: self.interfaceOrientation,
            originalSize: cameraImageResults.originalImageSize,
            depthImage: cameraImageResults.depthImage,
            confidenceImage: cameraImageResults.confidenceImage,
            captureImageDataResults: captureImageDataResults,
            captureMeshDataResults: captureMeshDataResults
        )
        return capturedData
    }
    
    @MainActor
    func pause() throws {
        self.outputConsumer?.pauseSession()
        self.cameraImageResults = nil
        self.cameraMeshResults = nil
        self.meshGPUSnapshotGenerator?.reset()
        self.cameraCache = ARCameraCache()
    }
        
    @MainActor
    func resume() throws {
        self.outputConsumer?.resumeSession()
    }
}
