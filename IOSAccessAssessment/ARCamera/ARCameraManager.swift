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
        interfaceOrientation: UIInterfaceOrientation, originalImageSize: CGSize,
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
    var meshGPUSnapshot: MeshGPUSnapshot
    
    var meshAnchors: [ARMeshAnchor] = []
    var segmentationLabelImage: CIImage
    var cameraTransform: simd_float4x4
    var cameraIntrinsics: simd_float3x3
    
    var lastUpdated: TimeInterval
    
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
    
    // TODO: Try to Initialize the context once and share across the app
    var meshGPUContext: MeshGPUContext? = nil
    var isConfigured: Bool {
        return (segmentationPipeline != nil) && (meshGPUSnapshotGenerator != nil)
    }
    
    // Consumer that will receive processed overlays (weak to avoid retain cycles)
    weak var outputConsumer: ARSessionCameraProcessingOutputConsumer? = nil
    var imageResolution: CGSize = .zero
    @Published var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    var frameRate: Int = 15
    var lastFrameTime: TimeInterval = 0
    var meshFrameRate: Int = 15
    var lastMeshFrameTime: TimeInterval = 0
    
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
    
    var cameraImageResults: ARCameraImageResults?
    var cameraMeshResults: ARCameraMeshResults?
    var cameraCache: ARCameraCache = ARCameraCache()
    
    override init() {
        super.init()
    }
    
    func configure(
        selectedClasses: [AccessibilityFeatureClass], segmentationPipeline: SegmentationARPipeline
    ) throws {
        self.selectedClasses = selectedClasses
        self.segmentationPipeline = segmentationPipeline
        
        // TODO: Create the device once and share across the app
        let device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            throw ARCameraManagerError.metalDeviceUnavailable
        }
        self.meshGPUSnapshotGenerator = MeshGPUSnapshotGenerator(device: device)
        self.meshGPUContext = try MeshGPUContext(device: device)
        try setUpPreAllocatedPixelBufferPools(size: Constants.SelectedAccessibilityFeatureConfig.inputSize)
        
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
                 await MainActor.run {
                     self.cameraImageResults = {
                        var results = cameraImageResults
                        results.depthImage = depthImage
                        results.confidenceImage = confidenceImage
                        return results
                     }()
                     self.outputConsumer?.cameraManagerImage(
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
        guard checkMeshWithinMeshFrameRate(currentTime: Date().timeIntervalSince1970) else {
            return
        }
        guard let meshGPUContext = meshGPUContext else {
            return
        }
        Task {
            do {
                let cameraMeshResults = try await processMeshAnchors(anchors)
                await MainActor.run {
                    self.cameraMeshResults = cameraMeshResults
                    self.outputConsumer?.cameraManagerMesh(
                        self, meshGPUContext: meshGPUContext,
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
        guard let meshGPUContext = meshGPUContext else {
            return
        }
        Task {
            do {
                let cameraMeshResults = try await processMeshAnchors(anchors)
                await MainActor.run {
                    self.cameraMeshResults = cameraMeshResults
                    self.outputConsumer?.cameraManagerMesh(
                        self, meshGPUContext: meshGPUContext,
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
        guard let meshGPUContext = meshGPUContext else {
            return
        }
        Task {
            do {
                let cameraMeshResults = try await processMeshAnchors(anchors, shouldRemove: true)
                await MainActor.run {
                    self.cameraMeshResults = cameraMeshResults
                    self.outputConsumer?.cameraManagerMesh(
                        self, meshGPUContext: meshGPUContext,
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
        guard let cameraPixelBufferPool = cameraPixelBufferPool,
              let segmentationPixelBufferPool = segmentationPixelBufferPool else {
            throw ARCameraManagerError.pixelBufferPoolCreationFailed
        }
        guard let segmentationPipeline = segmentationPipeline else {
            throw ARCameraManagerError.segmentationNotConfigured
        }
        let originalSize: CGSize = image.extent.size
        let croppedSize = AccessibilityFeatureConfig.mapillaryCustom11Config.inputSize
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
        
        let segmentationResults: SegmentationARPipelineResults = try await segmentationPipeline.processRequest(
            with: renderedCameraImage, highPriority: highPriority
        )
        
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
        guard let segmentationFrameOrientedCGImage = ciContext.createCGImage(
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
            segmentationLabelImage: segmentationLabelImage,
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

// Functions to perform final session update
extension ARCameraManager {
    /**
    Perform any final updates to the AR session configuration that will be required by the caller.
     
     Runs the Image Segmentation Pipeline with high priority to ensure that the latest frame.
     Currently, will not run the Mesh Processing Pipeline since it is generally performed on the main thread.
     */
    @MainActor
    func performFinalSessionUpdate() async throws -> CaptureData {
        guard let capturedMeshSnapshotGenerator = self.capturedMeshSnapshotGenerator,
              let cameraMeshResults = self.cameraMeshResults
        else {
            throw ARCameraManagerError.finalSessionNotConfigured
        }
        
        guard let pixelBuffer = self.cameraImageResults?.cameraImage,
              let depthImage = self.cameraImageResults?.depthImage,
              let cameraTransform = self.cameraImageResults?.cameraTransform,
              let cameraIntrinsics = self.cameraImageResults?.cameraIntrinsics
        else {
            throw ARCameraManagerError.cameraImageResultsUnavailable
        }
        var cameraImageResults = try await self.processCameraImage(
            image: pixelBuffer, interfaceOrientation: self.interfaceOrientation,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics,
            highPriority: true
        )
        cameraImageResults.depthImage = depthImage
        cameraImageResults.confidenceImage = self.cameraImageResults?.confidenceImage
        
        guard let cameraMeshRecordDetails = outputConsumer?.getMeshRecordDetails()
        else {
            throw ARCameraManagerError.finalSessionMeshUnavailable
        }
        let cameraMeshRecords = cameraMeshRecordDetails.records
        
        var vertexStride, vertexOffset, indexStride, classificationStride: Int
        if let cameraMeshOtherDetails = cameraMeshRecordDetails.otherDetails {
            vertexStride = cameraMeshOtherDetails.vertexStride
            vertexOffset = cameraMeshOtherDetails.vertexOffset
            indexStride = cameraMeshOtherDetails.indexStride
            classificationStride = cameraMeshOtherDetails.classificationStride
        } else {
            // If other details are not provided, use from the last processed mesh results
            // WARNING: This risks mismatch if the outputConsumer changed the mesh processing parameters in between
            // But the assumption is that if the outputConsumer is not providing the details, it is not changing them either
            vertexStride = cameraMeshResults.meshGPUSnapshot.vertexStride
            vertexOffset = cameraMeshResults.meshGPUSnapshot.vertexOffset
            indexStride = cameraMeshResults.meshGPUSnapshot.indexStride
            classificationStride = cameraMeshResults.meshGPUSnapshot.classificationStride
        }
        
        let cameraMeshSnapshot = capturedMeshSnapshotGenerator.snapshotSegmentationRecords(
            from: cameraMeshRecords,
            vertexStride: vertexStride,
            vertexOffset: vertexOffset,
            indexStride: indexStride,
            classificationStride: classificationStride
        )
        let captureDataResults = CaptureDataResults(
            segmentationLabelImage: cameraImageResults.segmentationLabelImage,
            segmentedClasses: cameraImageResults.segmentedClasses,
            detectedObjectMap: cameraImageResults.detectedObjectMap,
            segmentedMesh: cameraMeshSnapshot
        )
        
        let capturedData = CaptureData(
            id: UUID(),
            interfaceOrientation: self.interfaceOrientation,
            timestamp: Date().timeIntervalSince1970,
            cameraImage: cameraImageResults.cameraImage,
            depthImage: cameraImageResults.depthImage,
            confidenceImage: cameraImageResults.confidenceImage,
            cameraTransform: cameraImageResults.cameraTransform,
            cameraIntrinsics: cameraImageResults.cameraIntrinsics,
            captureDataResults: captureDataResults,
        )
        return capturedData
    }
}
