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

final class AnnotationImageManager: NSObject, ObservableObject, AnnotationImageProcessingDelegate {
    private var selectedClasses: [AccessibilityFeatureClass] = []
    private var segmentationAnnotationPipeline: SegmentationAnnotationPipeline? = nil
    private var grayscaleToColorFilter: GrayscaleToColorFilter? = nil
    
    weak var outputConsumer: AnnotationImageProcessingOutputConsumer? = nil
    @Published var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    private let context = CIContext(options: nil)
    
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
        captureImageData: (any CaptureImageDataProtocol),
        captureDataHistory: [CaptureImageData]
    ) {
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
    func updateFeatureClass(
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol),
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> [AccessibilityFeature] {
        guard isConfigured else {
            throw AnnotationImageManagerError.notConfigured
        }
        guard var annotationImageResults = self.annotationImageResults,
              let cameraOutputImage = annotationImageResults.cameraOutputImage else {
            throw AnnotationImageManagerError.imageResultCacheFailed
        }
//        let polygonsNormalizedCoordinates = try getPolygonsNormalizedCoordinates(
//            captureImageData: captureImageData,
//            captureMeshData: captureMeshData,
//            accessibilityFeatureClass: accessibilityFeatureClass
//        )
//        let meshOverlayOutputImage = try getMeshOverlayOutputImage(
//            captureMeshData: captureMeshData,
//            polygonsNormalizedCoordinates: polygonsNormalizedCoordinates, size: captureImageData.originalSize,
//            accessibilityFeatureClass: accessibilityFeatureClass
//        )
        let processedSegmentationLabelImage = getProcessedSegmentationLabelImage(
            captureImageData: captureImageData,
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        let segmentationOverlayOutputImage = try getSegmentationOverlayOutputImage(
            captureImageData: captureImageData,
            segmentationLabelImage: processedSegmentationLabelImage,
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        let accessibilityFeatures = try getAccessibilityFeatures(
            segmentationLabelImage: processedSegmentationLabelImage,
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        let featuresOverlayResults = try getFeaturesOverlayOutputImageWithSource(
            captureImageData: captureImageData,
            accessibilityFeatures: accessibilityFeatures
        )
        let featuresSourceCGImage = featuresOverlayResults.sourceCGImage
        let featuresOverlayOutputImage = featuresOverlayResults.overlayImage
        annotationImageResults.processedSegmentationLabelImage = processedSegmentationLabelImage
        annotationImageResults.segmentationOverlayOutputImage = segmentationOverlayOutputImage
        annotationImageResults.featuresSourceCGImage = featuresSourceCGImage
        annotationImageResults.featuresOverlayOutputImage = featuresOverlayOutputImage
        self.annotationImageResults = annotationImageResults
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
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol),
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [AccessibilityFeature],
        isSelected: Bool
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
            captureImageData: captureImageData,
            sourceCGImage: featuresSourceCGImage,
            accessibilityFeatures: accessibilityFeatures,
            isSelected: isSelected
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
    private func getAlignedCaptureDataHistory(
        captureImageData: (any CaptureImageDataProtocol),
        captureDataHistory: [CaptureImageData]
    ) -> [CIImage] {
        do {
            guard let segmentationAnnotationPipeline = self.segmentationAnnotationPipeline else {
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
        captureImageData: (any CaptureImageDataProtocol),
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) -> CIImage {
        do {
            guard let segmentationAnnotationPipeline = self.segmentationAnnotationPipeline else {
                throw AnnotationImageManagerError.segmentationNotConfigured
            }
            let processedSegmentationLabelImage = try segmentationAnnotationPipeline.processUnionOfMasksRequest(
                accessibilityFeatureClass: accessibilityFeatureClass
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
    ) throws -> [AccessibilityFeature] {
        guard let segmentationAnnotationPipeline = self.segmentationAnnotationPipeline else {
            throw AnnotationImageManagerError.segmentationNotConfigured
        }
        let detectedFeatures = try segmentationAnnotationPipeline.processContourRequest(
            segmentationLabelImage: segmentationLabelImage,
            accessibilityFeatureClass: accessibilityFeatureClass
        )
        let accessibilityFeatures = detectedFeatures.map { detectedFeature in
            return AccessibilityFeature(
                accessibilityFeatureClass: detectedFeature.accessibilityFeatureClass,
                detectedAccessibilityFeature: detectedFeature
            )
        }
        return accessibilityFeatures
    }
    
    private func getFeaturesOverlayOutputImageWithSource(
        captureImageData: (any CaptureImageDataProtocol),
        accessibilityFeatures: [AccessibilityFeature]
    ) throws -> (sourceCGImage: CGImage, overlayImage: CIImage) {
        guard let raterizedFeaturesImage = ContourFeatureRasterizer.rasterizeFeatures(
            accessibilityFeatures: accessibilityFeatures, size: captureImageData.originalSize,
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
        captureImageData: (any CaptureImageDataProtocol),
        sourceCGImage: CGImage,
        accessibilityFeatures: [AccessibilityFeature],
        isSelected: Bool
    ) throws -> (sourceCGImage: CGImage, overlayImage: CIImage) {
        let size = CGSize(width: sourceCGImage.width, height: sourceCGImage.height)
        let color: UIColor? = isSelected ? UIColor.white : nil
        guard let updatedRasterizedFeaturesImage = ContourFeatureRasterizer.updateRasterizedFeatures(
            baseImage: sourceCGImage,
            accessibilityFeatures: accessibilityFeatures, size: size,
            polygonConfig: RasterizeConfig(draw: true, color: color, width: 5),
            boundsConfig: RasterizeConfig(draw: false, color: color, width: 0),
            centroidConfig: RasterizeConfig(draw: true, color: color, width: 10)
        ) else {
            throw AnnotationImageManagerError.featureRasterizationFailed
        }
        let overlayImage = try createFeaturesOverlayFromSource(
            raterizedFeaturesImage: updatedRasterizedFeaturesImage,
            interfaceOrientation: captureImageData.interfaceOrientation
        )
        return (sourceCGImage: updatedRasterizedFeaturesImage, overlayImage: overlayImage)
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
    ) throws -> [(SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)] {
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
