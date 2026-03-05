//
//  TestCameraManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/5/26.
//

import ARKit
import RealityKit
import Combine
import simd

final class TestCameraManager: NSObject, ObservableObject, ARSessionCameraProcessingDelegate {
    var selectedClasses: [AccessibilityFeatureClass] = []
    var segmentationPipeline: SegmentationARPipeline? = nil
    var cameraOutputImageCallback: ((any CaptureImageDataProtocol) -> Void)? = nil
    
    // Consumer that will receive processed overlays (weak to avoid retain cycles)
    weak var outputConsumer: ARSessionCameraProcessingOutputConsumer? = nil
    
    // Contexts depending on type of color space processing required
    let colorContext = CIContext(options: nil)
    
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
        cameraOutputImageCallback: ((any CaptureImageDataProtocol) -> Void)? = nil
    ) throws {
        self.selectedClasses = selectedClasses
        self.segmentationPipeline = segmentationPipeline
        
        self.cameraOutputImageCallback = cameraOutputImageCallback
        self.isConfigured = true
    }
    
    func setVideoFormatImageResolution(_ imageResolution: CGSize) {
        /// Do nothing for now
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientation) {
        /// Do nothing for now
    }
}

extension TestCameraManager {
    func handleSessionFrameUpdate(datasetCaptureData: DatasetCaptureData) {
        guard isConfigured else {
            return
        }
        let cameraTransform = datasetCaptureData.captureImageData.cameraTransform
        let cameraIntrinsics = datasetCaptureData.captureImageData.cameraIntrinsics
        let cameraImage = datasetCaptureData.captureImageData.cameraImage
        let depthImage = datasetCaptureData.captureImageData.depthImage
        
        
    }
    
    private func processCameraImage(
        image: CIImage,
        depthImage: CIImage? = nil,
        interfaceOrientation: UIInterfaceOrientation,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        originalSize: CGSize
    ) async throws -> ARCameraImageResults {
        guard let segmentationPipeline = segmentationPipeline else {
            throw ARCameraManagerError.segmentationNotConfigured
        }
        let croppedSize = Constants.SelectedAccessibilityFeatureConfig.inputSize
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: interfaceOrientation
        )
        let inverseOrientation = imageOrientation.inverted()
        
        let orientedImage = image.oriented(imageOrientation)
        let inputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        var inputDepthImage: CIImage? = nil
        if let depthImage = depthImage {
            /// Pre-process the depth image: resize to image original size, orient, center-crop, and back to pixel buffer
            let resizedDepthImage = depthImage.resized(to: originalSize)
            let orientedDepthImage = resizedDepthImage.oriented(imageOrientation)
            let inputDepthImage = CenterCropTransformUtils.centerCropAspectFit(orientedDepthImage, to: croppedSize)
        }
        let segmentationResults: SegmentationARPipelineResults = try await segmentationPipeline.processRequest(
            with: inputImage, depthImage: inputDepthImage,
            highPriority: true
        )
        
        var segmentationImage = segmentationResults.segmentationImage
        segmentationImage = segmentationImage.oriented(inverseOrientation)
        segmentationImage = CenterCropTransformUtils.revertCenterCropAspectFit(segmentationImage, from: originalSize)
        /**
         ERROR: The segmentation mask cannot be backed by a pixel buffer after the revert center-crop transform, as it leads to unwanted downscaling of the values.
         Using Core Image for segmentation masks which are supposed to be numerically precise leads to such issues.
         */
//        segmentationImage = try self.backCIImageWithPixelBuffer(
//            segmentationImage, context: rawContext, pixelBufferPool: segmentationPixelBufferPool, colorSpace: segmentationMaskColorSpace
//        )
        
        var segmentationColorCIImage = segmentationResults.segmentationColorImage
        segmentationColorCIImage = segmentationColorCIImage.oriented(inverseOrientation)
        segmentationColorCIImage = CenterCropTransformUtils.revertCenterCropAspectFit(
            segmentationColorCIImage, from: originalSize
        )
        let segmentationColorImage = segmentationColorCIImage.oriented(imageOrientation)
        
        let detectedFeatureMap = alignDetectedFeatures(
            segmentationResults.detectedFeatureMap,
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
            depthImage: depthImage,
            segmentationLabelImage: segmentationImage,
            segmentedClasses: segmentationResults.segmentedClasses,
            detectedFeatureMap: detectedFeatureMap,
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics,
            interfaceOrientation: interfaceOrientation,
            originalImageSize: originalSize,
            segmentationColorImage: segmentationColorImage,
            segmentationBoundingFrameImage: segmentationBoundingFrameImage
        )
        return cameraImageResults
    }
    
    private func alignDetectedFeatures(
        _ detectedFeatureMap: [UUID: DetectedAccessibilityFeature],
        orientation: CGImagePropertyOrientation, imageSize: CGSize, originalSize: CGSize
    ) -> [UUID: DetectedAccessibilityFeature] {
        let orientationTransform = orientation.getNormalizedToUpTransform().inverted()
        // To revert the center-cropping effect to map back to original image size
        let revertTransform = CenterCropTransformUtils.revertCenterCropAspectFitNormalizedTransform(
            imageSize: imageSize, from: originalSize)
        let alignTransform = orientationTransform.concatenating(revertTransform)
        
        let alignedObjectMap: [UUID: DetectedAccessibilityFeature] = detectedFeatureMap.mapValues { object in
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
