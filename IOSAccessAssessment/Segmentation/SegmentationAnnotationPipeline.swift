//
//  SegmentationAnnotationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/10/25.
//

import SwiftUI
import Vision

import OrderedCollections
import simd

enum SegmentationAnnotationPipelineError: Error, LocalizedError {
    case isProcessingTrue
    case homographyTransformFilterNil
    case imageHistoryEmpty
    case unionOfMasksProcessorNil
    case contourRequestProcessorNil
    case homographyRequestProcessorNil
    case invalidUnionImageResult
    
    var errorDescription: String? {
        switch self {
        case .isProcessingTrue:
            return "The SegmentationAnnotationPipeline is already processing a request."
        case .homographyTransformFilterNil:
            return "Homography transform filter is not initialized."
        case .imageHistoryEmpty:
            return "Image data history is empty."
        case .unionOfMasksProcessorNil:
            return "Union of masks processor is not initialized."
        case .contourRequestProcessorNil:
            return "Contour request processor is not initialized."
        case .homographyRequestProcessorNil:
            return "Homography request processor is not initialized."
        case .invalidUnionImageResult:
            return "Failed to apply union of masks."
        }
    }
}

struct SegmentationAnnotationPipelineResults {
    var segmentationImage: CIImage
    var detectedFeatures: [DetectedAccessibilityFeature]
    
    init(segmentationImage: CIImage, detectedFeatures: [DetectedAccessibilityFeature]) {
        self.segmentationImage = segmentationImage
        self.detectedFeatures = detectedFeatures
    }
}

/**
 A class to handle the segmentation pipeline for annotation purposes.
 Unlike the main SegmentationPipeline, this class processes images and returns the results synchronously.
 Later, we can consider making it asynchronous based on the requirements.
 */
final class SegmentationAnnotationPipeline: ObservableObject {
    // This will be useful only when we are using the pipeline in asynchronous mode.
    var isProcessing = false
//    private var currentTask: Task<SegmentationARPipelineResults, Error>?
//    private var timeoutInSeconds: Double = 3.0
    
    private var selectedClasses: [AccessibilityFeatureClass] = []
    private var selectedClassLabels: [UInt8] = []
    private var selectedClassGrayscaleValues: [Float] = []
    private var selectedClassColors: [CIColor] = []
    
    // TODO: Check what would be the appropriate value for this
    var contourEpsilon: Float = 0.01
    // TODO: Check what would be the appropriate value for this
    // For normalized points
    var perimeterThreshold: Float = 0.2
    
    private var contourRequestProcessor: ContourRequestProcessor?
    private var homographyRequestProcessor: HomographyRequestProcessor?
    private var homographyTransformFilter: HomographyTransformFilter?
    private var unionOfMasksProcessor: UnionOfMasksProcessor?
    private var dimensionBasedMaskFilter: DimensionBasedMaskFilter?
    /// TODO: Replace with the global Metal context
    private let context = CIContext()
    
    func configure() throws {
        self.contourRequestProcessor = try ContourRequestProcessor(
            contourEpsilon: self.contourEpsilon,
            perimeterThreshold: self.perimeterThreshold,
            selectedClasses: self.selectedClasses)
        self.homographyRequestProcessor = HomographyRequestProcessor()
        self.homographyTransformFilter = try HomographyTransformFilter()
        self.dimensionBasedMaskFilter = try DimensionBasedMaskFilter()
        self.unionOfMasksProcessor = try UnionOfMasksProcessor()
    }
    
    func reset() {
        self.isProcessing = false
        self.setSelectedClasses([])
    }
    
    func setSelectedClasses(_ selectedClasses: [AccessibilityFeatureClass]) {
        self.selectedClasses = selectedClasses
        self.selectedClassLabels = selectedClasses.map { $0.labelValue }
        self.selectedClassGrayscaleValues = selectedClasses.map { $0.grayscaleValue }
        self.selectedClassColors = selectedClasses.map { $0.color }
        
        self.contourRequestProcessor?.setSelectedClasses(self.selectedClasses)
    }
    
    func processAlignImageDataRequest(
        currentCaptureData: CaptureImageData, captureDataHistory: [CaptureImageData]
    ) throws -> [CIImage] {
        if self.isProcessing {
            throw SegmentationAnnotationPipelineError.isProcessingTrue
        }
        guard let homographyTransformFilter = self.homographyTransformFilter,
              let unionOfMasksProcessor = self.unionOfMasksProcessor else {
            throw SegmentationAnnotationPipelineError.homographyTransformFilterNil
        }
        self.isProcessing = true
        
        guard captureDataHistory.count > 1 else {
            self.isProcessing = false
            guard captureDataHistory.count == 1 else {
                throw SegmentationAnnotationPipelineError.imageHistoryEmpty
            }
            let mainSegmentationLabelImage = captureDataHistory[0].captureImageDataResults.segmentationLabelImage
            return [mainSegmentationLabelImage]
        }
        
        /**
         Iterate through the image data history in reverse.
         Process each image by applying the homography transforms of the successive images.
         
         TODO: Need to check if the error handling is appropriate here.
         */
        var alignedSegmentationLabelImages: [CIImage] = []
        var referenceCaptureData = currentCaptureData
        /// Identity matrix for the first image
        var transformMatrixToNextFrame: simd_float3x3 = matrix_identity_float3x3
        for captureData in captureDataHistory.reversed() {
            do {
                let homographyTransform = try self.getHomographyTransform(
                    referenceCaptureData: referenceCaptureData, currentCaptureData: captureData
                )
                transformMatrixToNextFrame = homographyTransform * transformMatrixToNextFrame
                let transformedImage = try homographyTransformFilter.apply(
                    to: captureData.captureImageDataResults.segmentationLabelImage,
                    transformMatrix: transformMatrixToNextFrame
                )
                alignedSegmentationLabelImages.append(transformedImage)
                referenceCaptureData = captureData
            } catch {
                print("Error getting homography transform: \(error)")
                continue
            }
        }
        
        self.isProcessing = false
        try unionOfMasksProcessor.setArrayTexture(images: alignedSegmentationLabelImages)
        return alignedSegmentationLabelImages
    }
    
    /**
     This function uses the homography request processor to compute the homography matrix
     */
    private func getHomographyTransform(
        referenceCaptureData: CaptureImageData, currentCaptureData: CaptureImageData
    ) throws -> simd_float3x3 {
        guard let homographyRequestProcessor = self.homographyRequestProcessor else {
            throw SegmentationAnnotationPipelineError.homographyRequestProcessorNil
        }
        let homographyTransform = try homographyRequestProcessor.getHomographyTransform(
            referenceImage: referenceCaptureData.cameraImage, floatingImage: currentCaptureData.cameraImage
        )
        return homographyTransform
    }
    
    func processUnionOfMasksRequest(targetValue: UInt8, bounds: DimensionBasedMaskBounds? = nil,
                                    unionOfMasksPolicy: UnionOfMasksPolicy = .default) throws -> CIImage {
        if self.isProcessing {
            throw SegmentationAnnotationPipelineError.isProcessingTrue
        }
        self.isProcessing = true
        
        guard let unionOfMasksProcessor = self.unionOfMasksProcessor else {
            throw SegmentationAnnotationPipelineError.unionOfMasksProcessorNil
        }
        
        var unionImage = try unionOfMasksProcessor.apply(targetValue: targetValue, unionOfMasksPolicy: unionOfMasksPolicy)
        if bounds != nil {
//            print("Applying dimension-based mask filter")
            unionImage = try self.dimensionBasedMaskFilter?.apply(
                to: unionImage, bounds: bounds!) ?? unionImage
        }
        
        self.isProcessing = false
        
        // Back the CIImage to a pixel buffer
        unionImage = self.backCIImageToPixelBuffer(unionImage)
        return unionImage
    }
    
    private func backCIImageToPixelBuffer(_ image: CIImage) -> CIImage {
        var imageBuffer: CVPixelBuffer?
        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:] // Required for Metal/CoreImage
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.extent.width),
            Int(image.extent.height),
            kCVPixelFormatType_OneComponent8,
            attributes as CFDictionary,
            &imageBuffer
        )
        guard status == kCVReturnSuccess, let imageBuffer = imageBuffer else {
            print("Error: Failed to create pixel buffer")
            return image
        }
        // Render the CIImage to the pixel buffer
        self.context.render(image, to: imageBuffer, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceGray())
        // Create a CIImage from the pixel buffer
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        return ciImage
    }
        
}
