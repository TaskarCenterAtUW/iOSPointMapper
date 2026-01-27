//
//  AnnotationImageManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/15/25.
//
import SwiftUI
import DequeModule

enum AnnotationImageManagerError: Error, LocalizedError {
    case notConfigured
    case segmentationNotConfigured
    case captureDataNotAvailable
    case imageHistoryNotAvailable
    case cameraImageProcessingFailed
    case imageResultCacheFailed
    case segmentationImageRasterizationFailed
    case featureRasterizationFailed
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
        case .featureRasterizationFailed:
            return "Failed to rasterize the features."
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
    var featuresSourceCGImage: CGImage? = nil
    
    var cameraOutputImage: CIImage? = nil
    var segmentationOverlayOutputImage: CIImage? = nil
    var featuresOverlayOutputImage: CIImage? = nil
}

struct AnnotationImageFeatureUpdateResults: Sendable {
    let plane: Plane?
    let projectedPlane: ProjectedPlane?
}

/**
    A class to manage annotation image processing including segmentation mask post-processing and feature detection.
 */
final class AnnotationImageManager: NSObject, ObservableObject, AnnotationImageProcessingDelegate {
    private var selectedClasses: [AccessibilityFeatureClass] = []
    private var segmentationAnnotationPipeline: SegmentationAnnotationPipeline? = nil
    private var grayscaleToColorFilter: GrayscaleToColorFilter? = nil
    
    private var captureImageData: (any CaptureImageDataProtocol)? = nil
    private var captureMeshData: (any CaptureMeshDataProtocol)? = nil
    var isEnhancedAnalysisEnabled: Bool = false
    
    weak var outputConsumer: AnnotationImageProcessingOutputConsumer? = nil
    @Published var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    private let context = CIContext(options: nil)
    
    @Published var isConfigured: Bool = false
    
    // Latest processed results
    var annotationImageResults: AnnotationImageResults?
    
    /// TODO: MESH PROCESSING: Integrate mesh data processing in the annotation image manager.
    func configure(
        selectedClasses: [AccessibilityFeatureClass], segmentationAnnotationPipeline: SegmentationAnnotationPipeline,
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol)?,
        isEnhancedAnalysisEnabled: Bool
    ) throws {
        self.selectedClasses = selectedClasses
        self.segmentationAnnotationPipeline = segmentationAnnotationPipeline
        self.captureImageData = captureImageData
        self.captureMeshData = captureMeshData
        self.isEnhancedAnalysisEnabled = isEnhancedAnalysisEnabled
        
        let cameraOutputImage = try getCameraOutputImage()
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
                    self, image: cameraOutputImage, overlayImage: nil, overlay2Image: nil
                )
            }
        }
    }
    
    /**
        Sets up aligned segmentation label images from the capture data history.
        MARK: Does not throw errors, since this is not critical to the annotation image processing.
     */
    func setupAlignedSegmentationLabelImages(
        captureDataHistory: [CaptureImageData]
    ) {
        guard let _ = self.captureImageData,
              var annotationImageResults = self.annotationImageResults else {
            return
        }
        let alignedSegmentationLabelImages = getAlignedCaptureDataHistory(captureDataHistory: captureDataHistory)
        annotationImageResults.alignedSegmentationLabalImages = alignedSegmentationLabelImages
        self.annotationImageResults = annotationImageResults
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientation) {
        Task {
            await MainActor.run {
                self.interfaceOrientation = orientation
            }
        }
    }
    
    /**
     Updates the camera image, and recreates the overlay image.
     */
    func updateFeatureClass(
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> [EditableAccessibilityFeature] {
        guard isConfigured else {
            throw AnnotationImageManagerError.notConfigured
        }
        guard let captureImageData = self.captureImageData,
              var annotationImageResults = self.annotationImageResults,
              let cameraOutputImage = annotationImageResults.cameraOutputImage else {
            throw AnnotationImageManagerError.imageResultCacheFailed
        }
        var processedSegmentationLabelImage: CIImage
        do {
            processedSegmentationLabelImage = try getProcessedSegmentationLabelImage(
                accessibilityFeatureClass: accessibilityFeatureClass
            )
        } catch {
            processedSegmentationLabelImage = captureImageData.captureImageDataResults.segmentationLabelImage
        }
        let segmentationOverlayOutputImage = try getSegmentationOverlayOutputImage(
            segmentationLabelImage: processedSegmentationLabelImage,
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        let accessibilityFeatures = try getAccessibilityFeatures(
            segmentationLabelImage: processedSegmentationLabelImage,
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        let featuresOverlayResults = try getFeaturesOverlayOutputImageWithSource(
            accessibilityFeatures: accessibilityFeatures
        )
        let featuresSourceCGImage = featuresOverlayResults.sourceCGImage
        let featuresOverlayOutputImage = featuresOverlayResults.overlayImage
        annotationImageResults.processedSegmentationLabelImage = processedSegmentationLabelImage
        annotationImageResults.segmentationOverlayOutputImage = segmentationOverlayOutputImage
        annotationImageResults.featuresSourceCGImage = featuresSourceCGImage
        annotationImageResults.featuresOverlayOutputImage = featuresOverlayOutputImage
        self.annotationImageResults = annotationImageResults
        
        /// TODO: Mesh-based overlay processing to be added here.
//        if isEnhancedAnalysisEnabled,
//           let captureMeshData = self.captureMeshData {
//            let polygonsNormalizedCoordinates = try getPolygonsNormalizedCoordinates(
//                captureImageData: captureImageData,
//                captureMeshData: captureMeshData,
//                accessibilityFeatureClass: accessibilityFeatureClass
//            )
//            let meshOverlayOutputImage = try getMeshOverlayOutputImage(
//                captureMeshData: captureMeshData,
//                polygonsNormalizedCoordinates: polygonsNormalizedCoordinates, size: captureImageData.originalSize,
//                accessibilityFeatureClass: accessibilityFeatureClass
//            )
//        }
        
        Task {
            await MainActor.run {
                self.outputConsumer?.annotationOutputImage(
                    self,
                    image: cameraOutputImage,
                    overlayImage: segmentationOverlayOutputImage,
                    overlay2Image: featuresOverlayOutputImage
                )
            }
        }
        return accessibilityFeatures
    }
    
    func updateFeature(
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [EditableAccessibilityFeature],
        featureSelectedStatus: [UUID: Bool],
        updateFeatureResults: AnnotationImageFeatureUpdateResults
    ) throws {
        guard isConfigured else {
            throw AnnotationImageManagerError.notConfigured
        }
        guard var annotationImageResults = self.annotationImageResults,
              let cameraOutputImage = annotationImageResults.cameraOutputImage,
              let segmentationOverlayOutputImage = annotationImageResults.segmentationOverlayOutputImage,
              let featuresSourceCGImage = annotationImageResults.featuresSourceCGImage else {
            throw AnnotationImageManagerError.imageResultCacheFailed
        }
        let updatedFeaturesOverlayResults = try updateFeaturesOverlayOutputImageWithSource(
            sourceCGImage: featuresSourceCGImage,
            accessibilityFeatures: accessibilityFeatures,
            featureSelectedStatus: featureSelectedStatus
        )
        annotationImageResults.featuresSourceCGImage = updatedFeaturesOverlayResults.sourceCGImage
        annotationImageResults.featuresOverlayOutputImage = updatedFeaturesOverlayResults.overlayImage
        self.annotationImageResults = annotationImageResults
        Task {
            await MainActor.run {
                self.outputConsumer?.annotationOutputImage(
                    self,
                    image: cameraOutputImage,
                    overlayImage: segmentationOverlayOutputImage,
                    overlay2Image: updatedFeaturesOverlayResults.overlayImage
                )
            }
        }
    }
}

/**
    Extension to handle camera image processing: orientation and cropping.
 */
extension AnnotationImageManager {
    private func getCameraOutputImage() throws -> CIImage {
        guard let captureImageData = self.captureImageData else {
            throw AnnotationImageManagerError.captureDataNotAvailable
        }
        let cameraImage = captureImageData.cameraImage
        let interfaceOrientation = captureImageData.interfaceOrientation
//        let originalSize = captureImageData.originalSize
        let croppedSize = Constants.SelectedAccessibilityFeatureConfig.inputSize
        
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: interfaceOrientation
        )
        let orientedImage = cameraImage.oriented(imageOrientation)
        let cameraOutputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        guard let cameraCgImage = context.createCGImage(cameraOutputImage, from: cameraOutputImage.extent) else {
            throw AnnotationImageManagerError.cameraImageProcessingFailed
        }
        return CIImage(cgImage: cameraCgImage)
    }
}

/**
    Extension to handle segmentation mask post-processing.
 */
extension AnnotationImageManager {
    /**
        Aligns the segmentation label images from the capture data history to the current capture data.
        MARK: Does not throw errors, instead returns empty array on failure, since this is not critical to the annotation image processing.
     */
    private func getAlignedCaptureDataHistory(captureDataHistory: [CaptureImageData]) -> [CIImage] {
        do {
            guard let captureImageData = self.captureImageData,
                  let segmentationAnnotationPipeline = self.segmentationAnnotationPipeline else {
                throw AnnotationImageManagerError.segmentationNotConfigured
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
    
    private func getProcessedSegmentationLabelImage(
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> CIImage {
        guard let captureImageData = self.captureImageData else {
            throw AnnotationImageManagerError.captureDataNotAvailable
        }
        guard let segmentationAnnotationPipeline = self.segmentationAnnotationPipeline else {
            throw AnnotationImageManagerError.segmentationNotConfigured
        }
        let imageOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: captureImageData.interfaceOrientation
        )
        let processedSegmentationLabelImage = try segmentationAnnotationPipeline.processUnionOfMasksRequest(
            accessibilityFeatureClass: accessibilityFeatureClass,
            orientation: imageOrientation
        )
        return processedSegmentationLabelImage
    }
    
    private func getSegmentationOverlayOutputImage(
        segmentationLabelImage: CIImage,
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> CIImage {
        guard let captureImageData = self.captureImageData,
              let grayscaleToColorFilter = self.grayscaleToColorFilter else {
            throw AnnotationImageManagerError.notConfigured
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
        
        guard let overlayCgImage = context.createCGImage(overlayOutputImage, from: overlayOutputImage.extent) else {
            throw AnnotationImageManagerError.segmentationImageRasterizationFailed
        }
        return CIImage(cgImage: overlayCgImage)
    }
}

/**
 Extension to handle feature detection.
 */
extension AnnotationImageManager {
    private func getAccessibilityFeatures(
        segmentationLabelImage: CIImage,
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> [EditableAccessibilityFeature] {
        guard let segmentationAnnotationPipeline = self.segmentationAnnotationPipeline,
              let captureImageData = self.captureImageData else {
            throw AnnotationImageManagerError.segmentationNotConfigured
        }
        let imageOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: captureImageData.interfaceOrientation
        )
        let detectedFeatures = try segmentationAnnotationPipeline.processContourRequest(
            segmentationLabelImage: segmentationLabelImage,
            accessibilityFeatureClass: accessibilityFeatureClass,
            orientation: imageOrientation
        )
        let accessibilityFeatures = detectedFeatures.map { detectedFeature in
            return EditableAccessibilityFeature(
                detectedAccessibilityFeature: detectedFeature
            )
        }
        return accessibilityFeatures
    }
    
    private func getFeaturesOverlayOutputImageWithSource(accessibilityFeatures: [EditableAccessibilityFeature])
    throws -> (sourceCGImage: CGImage, overlayImage: CIImage) {
        guard let captureImageData = self.captureImageData else {
            throw AnnotationImageManagerError.captureDataNotAvailable
        }
        guard let raterizedFeaturesImage = ContourFeatureRasterizer.rasterizeFeatures(
            detectedFeatures: accessibilityFeatures, size: captureImageData.originalSize,
            polygonConfig: RasterizeConfig(draw: true, color: nil, width: 5),
            boundsConfig: RasterizeConfig(draw: false, color: nil, width: 0),
            centroidConfig: RasterizeConfig(draw: true, color: nil, width: 10)
        ) else {
            throw AnnotationImageManagerError.featureRasterizationFailed
        }
        let overlayImage = try createFeaturesOverlayFromSource(
            raterizedFeaturesImage: raterizedFeaturesImage,
            interfaceOrientation: captureImageData.interfaceOrientation
        )
        return (sourceCGImage: raterizedFeaturesImage, overlayImage: overlayImage)
    }
    
    private func updateFeaturesOverlayOutputImageWithSource(
        sourceCGImage: CGImage,
        accessibilityFeatures: [EditableAccessibilityFeature],
        featureSelectedStatus: [UUID: Bool]
    ) throws -> (sourceCGImage: CGImage, overlayImage: CIImage) {
        guard let captureImageData = self.captureImageData else {
            throw AnnotationImageManagerError.captureDataNotAvailable
        }
        let size = CGSize(width: sourceCGImage.width, height: sourceCGImage.height)
        
        let isNotSelectedColor: UIColor? = nil
        let notSelectedFeatures = accessibilityFeatures.filter { feature in
            return !(featureSelectedStatus[feature.id] ?? false)
        }
        guard let updatedImageWithNotSelectedFeatures = ContourFeatureRasterizer.updateRasterizedFeatures(
            baseImage: sourceCGImage,
            detectedFeature: notSelectedFeatures, size: size,
            polygonConfig: RasterizeConfig(draw: true, color: isNotSelectedColor, width: 5),
            boundsConfig: RasterizeConfig(draw: false, color: isNotSelectedColor, width: 0),
            centroidConfig: RasterizeConfig(draw: true, color: isNotSelectedColor, width: 10)
        ) else {
            throw AnnotationImageManagerError.featureRasterizationFailed
        }
        let isSelectedColor: UIColor? = .white
        let selectedFeatures = accessibilityFeatures.filter { feature in
            return featureSelectedStatus[feature.id] ?? false
        }
        guard let updatedImageWithSelectedFeatures = ContourFeatureRasterizer.updateRasterizedFeatures(
            baseImage: updatedImageWithNotSelectedFeatures,
            detectedFeature: selectedFeatures, size: size,
            polygonConfig: RasterizeConfig(draw: true, color: isSelectedColor, width: 5),
            boundsConfig: RasterizeConfig(draw: false, color: isSelectedColor, width: 0),
            centroidConfig: RasterizeConfig(draw: true, color: isSelectedColor, width: 10)
        ) else {
            throw AnnotationImageManagerError.featureRasterizationFailed
        }
        let overlayImage = try createFeaturesOverlayFromSource(
            raterizedFeaturesImage: updatedImageWithSelectedFeatures,
            interfaceOrientation: captureImageData.interfaceOrientation
        )
        return (sourceCGImage: updatedImageWithSelectedFeatures, overlayImage: overlayImage)
    }
    
    private func createFeaturesOverlayFromSource(
        raterizedFeaturesImage: CGImage,
        interfaceOrientation: UIInterfaceOrientation
    ) throws -> CIImage {
        let raterizedFeaturesCIImage = CIImage(cgImage: raterizedFeaturesImage)
        let croppedSize = Constants.SelectedAccessibilityFeatureConfig.inputSize
        
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: interfaceOrientation
        )
        let orientedImage = raterizedFeaturesCIImage.oriented(imageOrientation)
        let overlayOutputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        guard let overlayCgImage = context.createCGImage(overlayOutputImage, from: overlayOutputImage.extent) else {
            throw AnnotationImageManagerError.segmentationImageRasterizationFailed
        }
        let overlayImage = CIImage(cgImage: overlayCgImage)
        return overlayImage
    }
}

/**
    Extension to handle mesh vertex processing and projection.
    Also handles rasterized mesh image orientation and cropping.
 
    TODO: MESH PROCESSING: Integrate mesh data processing in the annotation image manager.
 */
extension AnnotationImageManager {
    private func getMeshOverlayOutputImage(
        captureMeshData: (any CaptureMeshDataProtocol),
        polygonsNormalizedCoordinates: [(SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)],
        size: CGSize,
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> CIImage {
        guard let rasterizedMeshImage = MeshRasterizer.rasterizeMesh(
            polygonsNormalizedCoordinates: polygonsNormalizedCoordinates, size: size,
            boundsConfig: RasterizeConfig(color: UIColor(ciColor: accessibilityFeatureClass.color))
        ) else {
            throw AnnotationImageManagerError.meshRasterizationFailed
        }
        
        let rasterizedMeshCIImage = CIImage(cgImage: rasterizedMeshImage)
        let interfaceOrientation = captureMeshData.interfaceOrientation
        let croppedSize = Constants.SelectedAccessibilityFeatureConfig.inputSize
        
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: interfaceOrientation
        )
        let orientedImage = rasterizedMeshCIImage.oriented(imageOrientation)
        let overlayOutputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        guard let overlayCgImage = context.createCGImage(overlayOutputImage, from: overlayOutputImage.extent) else {
            throw AnnotationImageManagerError.meshRasterizationFailed
        }
        return CIImage(cgImage: overlayCgImage)
    }
    
    /**
     Retrieves mesh details (including vertex positions) for the given accessibility feature class, as normalized pixel coordinates.
     */
    private func getPolygonsNormalizedCoordinates(
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol),
        accessibilityFeatureClass: AccessibilityFeatureClass
    )
    throws -> [(SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)] {
        guard let captureImageData = self.captureImageData,
              let captureMeshData = self.captureMeshData else {
            throw AnnotationImageManagerError.captureDataNotAvailable
        }
        let meshPolygons = try CapturedMeshSnapshotHelper.readFeatureSnapshot(
            capturedMeshSnapshot: captureMeshData.captureMeshDataResults.segmentedMesh,
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        
        let cameraTransform = captureImageData.cameraTransform
        let viewMatrix = cameraTransform.inverse // world -> camera
        let cameraIntrinsics = captureImageData.cameraIntrinsics
        let originalSize = captureImageData.originalSize
        let polygonsCoordinates = MeshHelpers.getPolygonsCoordinates(
            meshPolygons: meshPolygons,
            viewMatrix: viewMatrix,
            cameraIntrinsics: cameraIntrinsics,
            originalSize: originalSize
        )
        
        let originalWidth = Float(originalSize.width)
        let originalHeight = Float(originalSize.height)
        let polygonsNormalizedCoordinates = polygonsCoordinates.map { (p0, p1, p2) in
            return (
                SIMD2<Float>(p0.x / originalWidth, p0.y / originalHeight),
                SIMD2<Float>(p1.x / originalWidth, p1.y / originalHeight),
                SIMD2<Float>(p2.x / originalWidth, p2.y / originalHeight)
            )
        }
        
        return polygonsNormalizedCoordinates
    }
}
