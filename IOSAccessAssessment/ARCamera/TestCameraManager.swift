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

final class TestCameraManager: NSObject, ObservableObject, TestCameraProcessingDelegate {
    var selectedClasses: [AccessibilityFeatureClass] = []
    var segmentationPipeline: SegmentationARPipeline? = nil
    var metalContext: MetalContext? = nil
    var cameraOutputImageCallback: ((any CaptureImageDataProtocol) -> Void)? = nil
    
    // Consumer that will receive processed overlays (weak to avoid retain cycles)
    weak var outputConsumer: TestCameraProcessingOutputConsumer? = nil
    @Published var interfaceOrientation: UIInterfaceOrientation = .portrait
    
    // Contexts depending on type of color space processing required
    let colorContext = CIContext(options: nil)
    let rawContext = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    // Properties for processing camera and depth frames
    // Pixel buffer pools for rendering camera frames to fixed size as segmentation model input (pre-defined size)
    var cameraColorSpace: CGColorSpace? = CGColorSpaceCreateDeviceRGB()
    var cameraPixelFormatType: OSType = kCVPixelFormatType_32BGRA
    var segmentationBoundingFrameColorSpace: CGColorSpace? = CGColorSpaceCreateDeviceRGB()
    var depthPixelFormatType: OSType = kCVPixelFormatType_DepthFloat32
    var depthColorSpace: CGColorSpace? = nil
    // Pixel buffer pools for backing segmentation images to pixel buffer of camera frame size
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
        metalContext: MetalContext?,
        cameraOutputImageCallback: ((any CaptureImageDataProtocol) -> Void)? = nil
    ) throws {
        self.selectedClasses = selectedClasses
        self.segmentationPipeline = segmentationPipeline
        
        guard let metalContext = metalContext else {
            throw ARCameraManagerError.metalDeviceUnavailable
        }
        self.metalContext = metalContext
        self.cameraOutputImageCallback = cameraOutputImageCallback
        self.isConfigured = true
    }
    
    func setVideoFormatImageResolution(_ imageResolution: CGSize) {
        /// Do nothing for now
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientation) {
        /// Do nothing for now
    }
    
    @MainActor
    func pause() throws {
        self.outputConsumer?.pauseSession()
        self.cameraImageResults = nil
        self.cameraMeshResults = nil
        self.cameraCache = ARCameraCache()
    }
}

/**
    Handles processing of camera frames from ARSession, including segmentation and alignment of detected features.
 */
extension TestCameraManager {
    func handleSessionFrameUpdate(datasetCaptureData: DatasetCaptureData) throws {
        guard isConfigured else {
            return
        }
        guard let metalContext = metalContext else {
            return
        }
        
        let cameraTransform = datasetCaptureData.captureImageData.cameraTransform
        let cameraIntrinsics = datasetCaptureData.captureImageData.cameraIntrinsics
        let cameraImage = datasetCaptureData.captureImageData.cameraImage
        let depthImage = datasetCaptureData.captureImageData.depthImage
        
        Task {
            do {
                let cameraImageResults = try await self.processCameraImage(
                    image: cameraImage, depthImage: depthImage,
                    interfaceOrientation: datasetCaptureData.captureImageData.interfaceOrientation,
                    cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics,
                    originalSize: datasetCaptureData.captureImageData.originalSize
                )
                let captureImageDataResults = CaptureImageDataResults(
                    segmentationLabelImage: cameraImageResults.segmentationLabelImage,
                    segmentedClasses: cameraImageResults.segmentedClasses,
                    detectedFeatureMap: cameraImageResults.detectedFeatureMap
                )
                let captureImageData = CaptureImageData(
                    id: UUID(),
                    timestamp: Date().timeIntervalSince1970,
                    cameraImage: cameraImageResults.cameraImage,
                    cameraTransform: cameraImageResults.cameraTransform,
                    cameraIntrinsics: cameraImageResults.cameraIntrinsics,
                    interfaceOrientation: cameraImageResults.interfaceOrientation,
                    originalSize: cameraImageResults.originalImageSize,
                    depthImage: cameraImageResults.depthImage,
                    confidenceImage: cameraImageResults.confidenceImage,
                    captureImageDataResults: captureImageDataResults
                )
                let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
                    currentInterfaceOrientation: datasetCaptureData.captureImageData.interfaceOrientation
                )
                await MainActor.run {
                    var results = cameraImageResults
                    results.depthImage = depthImage
                    results.confidenceImage = nil
                    self.cameraImageResults = results
                    self.outputConsumer?.cameraImage(
                        self, metalContext: metalContext,
                        cameraImage: cameraImageResults.cameraImage,
                        imageOrientation: imageOrientation,
                        for: nil
                    )
                    self.outputConsumer?.cameraOutputImage(
                        self, metalContext: metalContext,
                        segmentationImage: cameraImageResults.segmentationColorImage,
                        segmentationBoundingFrameImage: cameraImageResults.segmentationBoundingFrameImage,
                        for: nil
                    )
                    self.cameraOutputImageCallback?(captureImageData)
                    self.interfaceOrientation = datasetCaptureData.captureImageData.interfaceOrientation
                }
            } catch {
                print("Error processing camera image: \(error.localizedDescription)")
            }
        }
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
        var inputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        inputImage = try self.backCIImageWithPixelBuffer(
            inputImage, context: colorContext, pixelFormatType: cameraPixelFormatType, colorSpace: cameraColorSpace
        )
        
        var inputDepthImage: CIImage? = nil
        if let depthImage = depthImage {
            /// Pre-process the depth image: resize to image original size, orient, center-crop, and back to pixel buffer
            let resizedDepthImage = depthImage.resized(to: originalSize)
            let orientedDepthImage = resizedDepthImage.oriented(imageOrientation)
            let croppedDepthImage = CenterCropTransformUtils.centerCropAspectFit(orientedDepthImage, to: croppedSize)
            inputDepthImage = try self.backCIImageWithPixelBuffer(
                croppedDepthImage, context: rawContext, pixelFormatType: depthPixelFormatType, colorSpace: depthColorSpace
            )
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
        segmentationColorCIImage = segmentationColorCIImage.oriented(imageOrientation)
        let segmentationColorImage = try self.backCIImageWithPixelBuffer(
            segmentationColorCIImage, context: colorContext, pixelFormatType: segmentationColorPixelFormatType,
            colorSpace: segmentationColorColorSpace
        )
        
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

/**
 Handling final capture
 */
extension TestCameraManager {
    @MainActor
    func performFinalSessionUpdateIfPossible(
    ) async throws -> CaptureData {
        let captureData = try await performFinalSessionFrameUpdate()
        return .imageData(captureData)
    }
    
    @MainActor
    private func performFinalSessionFrameUpdate(
    ) async throws -> CaptureImageData {
        /// Process the latest camera image with high priority
        guard let cameraImage = self.cameraImageResults?.cameraImage,
              let cameraTransform = self.cameraImageResults?.cameraTransform,
              let cameraIntrinsics = self.cameraImageResults?.cameraIntrinsics,
              let originalImageSize = self.cameraImageResults?.originalImageSize
        else {
            throw ARCameraManagerError.cameraImageResultsUnavailable
        }
        let depthImage = self.cameraImageResults?.depthImage
        var cameraImageResults = try await self.processCameraImage(
            image: cameraImage, depthImage: depthImage,
            interfaceOrientation: self.interfaceOrientation,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics,
            originalSize: originalImageSize
        )
        guard cameraImageResults.segmentedClasses.count > 0 else {
            throw ARCameraManagerError.finalSessionNoSegmentationClass
        }
        cameraImageResults.depthImage = depthImage
        cameraImageResults.confidenceImage = self.cameraImageResults?.confidenceImage
        
        let captureImageDataResults = CaptureImageDataResults(
            segmentationLabelImage: cameraImageResults.segmentationLabelImage,
            segmentedClasses: cameraImageResults.segmentedClasses,
            detectedFeatureMap: cameraImageResults.detectedFeatureMap
        )
        
        let captureImageData = CaptureImageData(
            id: UUID(),
            timestamp: Date().timeIntervalSince1970,
            cameraImage: cameraImageResults.cameraImage,
            cameraTransform: cameraImageResults.cameraTransform,
            cameraIntrinsics: cameraImageResults.cameraIntrinsics,
            interfaceOrientation: self.interfaceOrientation,
            originalSize: cameraImageResults.originalImageSize,
            depthImage: cameraImageResults.depthImage,
            confidenceImage: cameraImageResults.confidenceImage,
            captureImageDataResults: captureImageDataResults
        )
        return captureImageData
    }
}

/**
 Handles backing of CIImage objects with CVPixelBuffer objects when needed.
 */
extension TestCameraManager {
    private func backCIImageWithPixelBuffer(
        _ ciImage: CIImage, context: CIContext,
        pixelFormatType: OSType, colorSpace: CGColorSpace? = nil,
    ) throws -> CIImage {
        let pixelBuffer = try ciImage.toPixelBuffer(context: context, pixelFormatType: pixelFormatType, colorSpace: colorSpace)
        let backedImage = CIImage(cvPixelBuffer: pixelBuffer)
        return backedImage
    }
}
