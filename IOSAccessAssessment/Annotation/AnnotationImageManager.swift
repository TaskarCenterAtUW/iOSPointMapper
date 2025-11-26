//
//  AnnotationImageManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/15/25.
//
import SwiftUI
import DequeModule

enum AnnotatiomImageManagerError: Error, LocalizedError {
    case notConfigured
    case segmentationNotConfigured
    case captureDataNotAvailable
    case imageHistoryNotAvailable
    case cameraImageProcessingFailed
    case imageResultCacheFailed
    case segmentationImageRasterizationFailed
    case meshClassNotFound(AccessibilityFeatureClass)
    case invalidMeshData
    case meshRasterizationFailed
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AnnotationImageManager is not configured."
        case .segmentationNotConfigured:
            return "SegmentationAnnotationPipeline is not configured."
        case .captureDataNotAvailable:
            return "Capture image data is not available."
        case .imageHistoryNotAvailable:
            return "Capture image data history is not available."
        case .cameraImageProcessingFailed:
            return "Failed to process the camera image."
        case .imageResultCacheFailed:
            return "Failed to retrieve the cached annotation image results."
        case .segmentationImageRasterizationFailed:
            return "Failed to rasterize the segmentation image."
        case .meshClassNotFound(let featureClass):
            return "No mesh found for the accessibility feature class: \(featureClass.name)."
        case .invalidMeshData:
            return "The mesh data is invalid."
        case .meshRasterizationFailed:
            return "Failed to rasterize the mesh into an image."
        }
    }
}

struct AnnotationImageResults {
    let cameraImage: CIImage
    
    let segmentationLabelImage: CIImage
    
    var alignedSegmentationLabalImages: [CIImage]?
    var processedSegmentationLabelImage: CIImage? = nil
    var cameraOutputImage: CIImage? = nil
    var overlayOutputImage: CIImage? = nil
}

final class AnnotationImageManager: NSObject, ObservableObject, AnnotationImageProcessingDelegate {
    private var selectedClasses: [AccessibilityFeatureClass] = []
    private var segmentationAnnotationPipeline: SegmentationAnnotationPipeline? = nil
    private var grayscaleToColorFilter: GrayscaleToColorFilter? = nil
    
    weak var outputConsumer: AnnotationImageProcessingOutputConsumer? = nil
    @Published var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    private let cIContext = CIContext(options: nil)
    
    @Published var isConfigured: Bool = false
    
    // Latest processed results
    var annotationImageResults: AnnotationImageResults?
    
    func configure(
        selectedClasses: [AccessibilityFeatureClass], segmentationAnnotationPipeline: SegmentationAnnotationPipeline,
        captureImageData: (any CaptureImageDataProtocol)
    ) throws {
        self.selectedClasses = selectedClasses
        self.segmentationAnnotationPipeline = segmentationAnnotationPipeline
        
        let cameraOutputImage = try getCameraOutputImage(
            captureImageData: captureImageData
        )
        let annotationImageResults: AnnotationImageResults = AnnotationImageResults(
            cameraImage: captureImageData.cameraImage,
            segmentationLabelImage: captureImageData.captureImageDataResults.segmentationLabelImage,
            cameraOutputImage: cameraOutputImage
        )
        self.annotationImageResults = annotationImageResults
        self.grayscaleToColorFilter = try GrayscaleToColorFilter()
        self.isConfigured = true
        
        Task {
            await MainActor.run {
                self.outputConsumer?.annotationOutputImage(
                    self, image: cameraOutputImage, overlayImage: nil
                )
            }
        }
    }
    
    /**
        Sets up aligned segmentation label images from the capture data history.
        MARK: Does not throw errors, since this is not critical to the annotation image processing.
     */
    func setupAlignedSegmentationLabelImages(
        captureImageData: (any CaptureImageDataProtocol),
        captureDataHistory: [CaptureImageData]
    ) async {
        guard var annotationImageResults = self.annotationImageResults else {
            return
        }
        let alignedSegmentationLabelImages = getAlignedCaptureDataHistory(
            captureImageData: captureImageData,
            captureDataHistory: captureDataHistory
        )
        annotationImageResults.alignedSegmentationLabalImages = alignedSegmentationLabelImages
        self.annotationImageResults = annotationImageResults
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientation) {
        self.interfaceOrientation = orientation
    }
    
    /**
     Updates the camera image, and recreates the overlay image.
     */
    func update(
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol),
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws {
        guard isConfigured else {
            throw AnnotatiomImageManagerError.notConfigured
        }
        guard var annotationImageResults = self.annotationImageResults,
              let cameraOutputImage = annotationImageResults.cameraOutputImage else {
            throw AnnotatiomImageManagerError.imageResultCacheFailed
        }
//        let trianglePointsNormalized = try getNormalizedTrianglePoints(
//            captureImageData: captureImageData,
//            captureMeshData: captureMeshData,
//            accessibilityFeatureClass: accessibilityFeatureClass
//        )
//        guard let rasterizedMeshImage = MeshRasterizer.rasterizeMesh(
//            trianglePointsNormalized: trianglePointsNormalized, size: captureImageData.originalSize,
//            boundsConfig: RasterizeConfig(color: UIColor(ciColor: accessibilityFeatureClass.color))
//        ) else {
//            throw AnnotatiomImageManagerError.meshRasterizationFailed
//        }
//        let overlayOutputImage = try getMeshOverlayOutputImage(
//            rasterizedMeshImage: rasterizedMeshImage,
//            captureMeshData: captureMeshData
//        )
        let processedSegmentationLabelImage = getProcessedSegmentationLabelImage(
            captureImageData: captureImageData,
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        let overlayOutputImage = try getSegmentationOverlayOutputImage(
            captureImageData: captureImageData,
            segmentationLabelImage: processedSegmentationLabelImage,
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        annotationImageResults.processedSegmentationLabelImage = processedSegmentationLabelImage
        annotationImageResults.overlayOutputImage = overlayOutputImage
        self.annotationImageResults = annotationImageResults
        Task {
            await MainActor.run {
                self.outputConsumer?.annotationOutputImage(
                    self,
                    image: cameraOutputImage,
                    overlayImage: overlayOutputImage
                )
            }
        }
    }
}

/**
    Extension to handle camera image processing: orientation and cropping.
 */
extension AnnotationImageManager {
    private func getCameraOutputImage(
        captureImageData: (any CaptureImageDataProtocol)
    ) throws -> CIImage {
        let cameraImage = captureImageData.cameraImage
        let interfaceOrientation = captureImageData.interfaceOrientation
//        let originalSize = captureImageData.originalSize
        let croppedSize = Constants.SelectedAccessibilityFeatureConfig.inputSize
        
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: interfaceOrientation
        )
        let orientedImage = cameraImage.oriented(imageOrientation)
        let cameraOutputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        guard let cameraCgImage = cIContext.createCGImage(cameraOutputImage, from: cameraOutputImage.extent) else {
            throw AnnotatiomImageManagerError.cameraImageProcessingFailed
        }
        return CIImage(cgImage: cameraCgImage)
    }
}

/**
    Extension to define a segmentation mask processing.
 */
extension AnnotationImageManager {
    /**
        Aligns the segmentation label images from the capture data history to the current capture data.
        MARK: Does not throw errors, instead returns empty array on failure, since this is not critical to the annotation image processing.
     */
    func getAlignedCaptureDataHistory(
        captureImageData: (any CaptureImageDataProtocol),
        captureDataHistory: [CaptureImageData]
    ) -> [CIImage] {
        do {
            guard let segmentationAnnotationPipeline = self.segmentationAnnotationPipeline else {
                throw AnnotatiomImageManagerError.segmentationNotConfigured
            }
            let currentCaptureData = CaptureImageData(captureImageData)
            let alignedSegmentationLabelImages: [CIImage] = try segmentationAnnotationPipeline.processAlignImageDataRequest(
                currentCaptureData: currentCaptureData, captureDataHistory: captureDataHistory
            )
            try segmentationAnnotationPipeline.setupUnionOfMasksRequest(
                alignedSegmentationLabelImages: alignedSegmentationLabelImages
            )
            return alignedSegmentationLabelImages
        } catch {
            print("Error aligning capture data history: \(error.localizedDescription)")
            return []
        }
    }
    
    func getProcessedSegmentationLabelImage(
        captureImageData: (any CaptureImageDataProtocol),
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) -> CIImage {
        do {
            guard let segmentationAnnotationPipeline = self.segmentationAnnotationPipeline else {
                throw AnnotatiomImageManagerError.segmentationNotConfigured
            }
            let targetValue = accessibilityFeatureClass.labelValue
            let bounds: DimensionBasedMaskBounds? = nil /// accessibilityFeatureClass.bounds
            let unionOfMasksPolicy = accessibilityFeatureClass.unionOfMasksPolicy
            let processedSegmentationLabelImage = try segmentationAnnotationPipeline.processUnionOfMasksRequest(
                targetValue: targetValue, bounds: bounds, unionOfMasksPolicy: unionOfMasksPolicy
            )
            return processedSegmentationLabelImage
        } catch {
            print("Error processing segmentation label image: \(error.localizedDescription)")
            return captureImageData.captureImageDataResults.segmentationLabelImage
        }
    }
    
    private func getSegmentationOverlayOutputImage(
        captureImageData: (any CaptureImageDataProtocol),
        segmentationLabelImage: CIImage,
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> CIImage {
        guard let grayscaleToColorFilter = self.grayscaleToColorFilter else {
            throw AnnotatiomImageManagerError.notConfigured
        }
        let segmentationColorImage = try grayscaleToColorFilter.apply(
            to: segmentationLabelImage,
            grayscaleValues: [accessibilityFeatureClass.grayscaleValue],
            colorValues: [accessibilityFeatureClass.color]
        )
        
        let interfaceOrientation = captureImageData.interfaceOrientation
        let croppedSize = Constants.SelectedAccessibilityFeatureConfig.inputSize
        
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: interfaceOrientation
        )
        let orientedImage = segmentationColorImage.oriented(imageOrientation)
        let overlayOutputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        guard let overlayCgImage = cIContext.createCGImage(overlayOutputImage, from: overlayOutputImage.extent) else {
            throw AnnotatiomImageManagerError.segmentationImageRasterizationFailed
        }
        return CIImage(cgImage: overlayCgImage)
    }
}

/**
    Extension to handle mesh vertex processing and projection.
    Also handles rasterized mesh image orientation and cropping.
 */
extension AnnotationImageManager {
    private func getMeshOverlayOutputImage(
        rasterizedMeshImage: CGImage,
        captureMeshData: (any CaptureMeshDataProtocol)
    ) throws -> CIImage {
        let rasterizedMeshCIImage = CIImage(cgImage: rasterizedMeshImage)
        let interfaceOrientation = captureMeshData.interfaceOrientation
        let croppedSize = Constants.SelectedAccessibilityFeatureConfig.inputSize
        
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: interfaceOrientation
        )
        let orientedImage = rasterizedMeshCIImage.oriented(imageOrientation)
        let overlayOutputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        guard let overlayCgImage = cIContext.createCGImage(overlayOutputImage, from: overlayOutputImage.extent) else {
            throw AnnotatiomImageManagerError.meshRasterizationFailed
        }
        return CIImage(cgImage: overlayCgImage)
    }
    
    private func getMeshCPUPolygons(
        captureMeshData: (any CaptureMeshDataProtocol),
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> [MeshCPUPolygon] {
        let capturedMeshSnapshot = captureMeshData.captureMeshDataResults.segmentedMesh
        guard let featureCapturedMeshSnapshot = capturedMeshSnapshot.anchors[accessibilityFeatureClass] else {
            throw AnnotatiomImageManagerError.meshClassNotFound(accessibilityFeatureClass)
        }
        
        let vertexStride: Int = capturedMeshSnapshot.vertexStride
        let vertexOffset: Int = capturedMeshSnapshot.vertexOffset
        let vertexData: Data = featureCapturedMeshSnapshot.vertexData
        let vertexCount: Int = featureCapturedMeshSnapshot.vertexCount
        let indexStride: Int = capturedMeshSnapshot.indexStride
        let indexData: Data = featureCapturedMeshSnapshot.indexData
        let indexCount: Int = featureCapturedMeshSnapshot.indexCount
        guard vertexCount > 0, vertexCount == indexCount else {
            throw AnnotatiomImageManagerError.invalidMeshData
        }
        
        var vertexPositions: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0,0,0), count: vertexCount)
        try vertexData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let baseAddress = ptr.baseAddress else {
                throw AnnotatiomImageManagerError.invalidMeshData
            }
            for i in 0..<vertexCount {
                let vertexAddress = baseAddress.advanced(by: i * vertexStride + vertexOffset)
                let vertexPointer = vertexAddress.assumingMemoryBound(to: SIMD3<Float>.self)
                vertexPositions[i] = vertexPointer.pointee
            }
        }
        
        var indexPositions: [UInt32] = Array(repeating: 0, count: indexCount)
        try indexData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let baseAddress = ptr.baseAddress else {
                throw AnnotatiomImageManagerError.invalidMeshData
            }
            for i in 0..<indexCount {
                let indexAddress = baseAddress.advanced(by: i * indexStride)
                let indexPointer = indexAddress.assumingMemoryBound(to: UInt32.self)
                indexPositions[i] = indexPointer.pointee
            }
        }
        
        var polygons: [MeshCPUPolygon] = []
        for i in 0..<(indexCount / 3) {
            let vi0 = Int(indexPositions[i*3])
            let vi1 = Int(indexPositions[i*3 + 1])
            let vi2 = Int(indexPositions[i*3 + 2])
            
            let polygon = MeshCPUPolygon(
                v0: vertexPositions[vi0],
                v1: vertexPositions[vi1],
                v2: vertexPositions[vi2],
                index0: vi0, index1: vi1, index2: vi2
            )
            polygons.append(polygon)
        }
        return polygons
    }
    
    /**
     Retrieves mesh details (including vertex positions) for the given accessibility feature class, as normalized pixel coordinates.
     */
    private func getNormalizedTrianglePoints(
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol),
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> [(SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)] {
        let capturedMeshSnapshot = captureMeshData.captureMeshDataResults.segmentedMesh
        guard let featureCapturedMeshSnapshot = capturedMeshSnapshot.anchors[accessibilityFeatureClass] else {
            throw AnnotatiomImageManagerError.meshClassNotFound(accessibilityFeatureClass)
        }
        let vertexStride: Int = capturedMeshSnapshot.vertexStride
        let vertexOffset: Int = capturedMeshSnapshot.vertexOffset
        let vertexData: Data = featureCapturedMeshSnapshot.vertexData
        let vertexCount: Int = featureCapturedMeshSnapshot.vertexCount
//        let indexStride: Int = capturedMeshSnapshot.indexStride
//        let indexData: Data = featureCapturedMeshSnapshot.indexData
//        let indexCount: Int = featureCapturedMeshSnapshot.indexCount
        
        let cameraTransform = captureImageData.cameraTransform
        let viewMatrix = cameraTransform.inverse // world -> camera
        let cameraIntrinsics = captureImageData.cameraIntrinsics
        let originalSize = captureImageData.originalSize
        
        var vertexPositions: [SIMD3<Float>] = Array(
            repeating: SIMD3<Float>(0,0,0),
            count: vertexCount
        )
        try vertexData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            guard let baseAddress = ptr.baseAddress else {
                throw AnnotatiomImageManagerError.invalidMeshData
            }
            for i in 0..<vertexCount {
                let vertexAddress = baseAddress.advanced(by: i * vertexStride + vertexOffset)
                let vertexPointer = vertexAddress.assumingMemoryBound(to: SIMD3<Float>.self)
                vertexPositions[i] = vertexPointer.pointee
            }
        }
        
        var trianglePoints: [(SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)] = []
        let originalWidth = Float(originalSize.width)
        let originalHeight = Float(originalSize.height)
        for i in 0..<(vertexCount / 3) {
            let (v0, v1, v2) = (vertexPositions[i*3], vertexPositions[i*3 + 1], vertexPositions[i*3 + 2])
            let worldPoints = [v0, v1, v2].map {
                projectWorldToPixel(
                    $0,
                    viewMatrix: viewMatrix,
                    intrinsics: cameraIntrinsics,
                    imageSize: originalSize
                )
            }
            guard let p0 = worldPoints[0],
                  let p1 = worldPoints[1],
                  let p2 = worldPoints[2] else {
                continue
            }
            let normalizedPoints = [p0, p1, p2].map {
                SIMD2<Float>(
                    $0.x / originalWidth,
                    $0.y / originalHeight
                )
            }
            trianglePoints.append((normalizedPoints[0], normalizedPoints[1], normalizedPoints[2]))
        }
        
        return trianglePoints
    }
    
    private func projectWorldToPixel(_ world: simd_float3,
                             viewMatrix: simd_float4x4, // (world->camera)
                             intrinsics K: simd_float3x3,
                             imageSize: CGSize) -> SIMD2<Float>? {
        let p4   = simd_float4(world, 1.0)
        let pc   = viewMatrix * p4                                  // camera space
        let x = pc.x, y = pc.y, z = pc.z
        
        guard z < 0 else {
            return nil
        }                       // behind camera
        
        // normalized image plane coords (flip Y so +Y goes up in pixels)
        let xn = x / -z
        let yn = -y / -z
        
        // intrinsics (column-major)
        let fx = K.columns.0.x
        let fy = K.columns.1.y
        let cx = K.columns.2.x
        let cy = K.columns.2.y
        
        // pixels in sensor/native image coordinates
        let u = fx * xn + cx
        let v = fy * yn + cy
        
        if u.isFinite && v.isFinite &&
            u >= 0 && v >= 0 &&
            u < Float(imageSize.width) && v < Float(imageSize.height) {
            return SIMD2<Float>(u.rounded(), v.rounded())
        }
        return nil
    }
}
