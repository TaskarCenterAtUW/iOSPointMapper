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

/**
 A class to handle the segmentation pipeline for annotation purposes.
 
 MARK: Unlike the main SegmentationPipeline, this class processes images and returns the results synchronously.
 Later, we can consider making it asynchronous based on the requirements.
 
 MARK: Also, instead of runnin the whole pipeline at once, this class needs to run individual steps of the pipeline separately, as they occur at different steps in the app flow.
 Hence, it gives full control to the caller to run the steps as needed.
 */
final class SegmentationAnnotationPipeline: ObservableObject {
    /// This will be useful only when we are using the pipeline in asynchronous mode.
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
        guard let homographyTransformFilter = self.homographyTransformFilter else {
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
                let segmentationLabelImage = captureData.captureImageDataResults.segmentationLabelImage
                let transformedImage = try homographyTransformFilter.apply(
                    to: segmentationLabelImage,
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
    
    func setupUnionOfMasksRequest(alignedSegmentationLabelImages: [CIImage]) throws {
        guard let unionOfMasksProcessor = self.unionOfMasksProcessor else {
            throw SegmentationAnnotationPipelineError.unionOfMasksProcessorNil
        }
        try unionOfMasksProcessor.setArrayTexture(images: alignedSegmentationLabelImages)
    }
    
    func processUnionOfMasksRequest(
        accessibilityFeatureClass: AccessibilityFeatureClass,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> CIImage {
        if self.isProcessing {
            throw SegmentationAnnotationPipelineError.isProcessingTrue
        }
        self.isProcessing = true
        
        guard let unionOfMasksProcessor = self.unionOfMasksProcessor else {
            throw SegmentationAnnotationPipelineError.unionOfMasksProcessorNil
        }
        
        let targetValue = accessibilityFeatureClass.labelValue
        let bounds: CGRect? = accessibilityFeatureClass.bounds
        let unionOfMasksPolicy = accessibilityFeatureClass.unionOfMasksPolicy
        var unionImage = try unionOfMasksProcessor.apply(targetValue: targetValue, unionOfMasksPolicy: unionOfMasksPolicy)
        if let bounds = bounds, let dimensionBasedMaskFilter = self.dimensionBasedMaskFilter {
            do {
                let transform = orientation.getNormalizedToUpTransform()
                let boundsTransformed = bounds.applying(transform)
                unionImage = try dimensionBasedMaskFilter.apply(to: unionImage, bounds: boundsTransformed)
            } catch {
                print("Error applying dimension based mask filter: \(error)")
            }
        }
        
        self.isProcessing = false
        
        return unionImage
    }
    
    func processContourRequest(
        segmentationLabelImage: CIImage, accessibilityFeatureClass: AccessibilityFeatureClass,
        orientation: CGImagePropertyOrientation = .up
    ) throws -> [DetectedAccessibilityFeature] {
        if self.isProcessing {
            throw SegmentationAnnotationPipelineError.isProcessingTrue
        }
        self.isProcessing = true
        guard var contourRequestProcessor = self.contourRequestProcessor else {
            throw SegmentationAnnotationPipelineError.contourRequestProcessorNil
        }
        
        contourRequestProcessor.setSelectedClasses([accessibilityFeatureClass])
        var detectedFeatures: [DetectedAccessibilityFeature] = try contourRequestProcessor.processRequest(
            from: segmentationLabelImage
        )
        /// TODO: Handle sidewalk feature differently if needed, and improve the relevant trapezoid-creation logic.
        let largestFeature = detectedFeatures.sorted(by: {$0.contourDetails.area > $1.contourDetails.area}).first
        guard let largestFeature = largestFeature,
              accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk else {
            self.isProcessing = false
            return detectedFeatures
        }
        let isTrapezoidFlipped = [.left, .leftMirrored, .right, .rightMirrored].contains(orientation)
        if let trapezoidPoints = ContourUtils.getTrapezoid(
            normalizedPoints: largestFeature.contourDetails.normalizedPoints,
            isFlipped: isTrapezoidFlipped
        ) {
            let trapezoidFeature = DetectedAccessibilityFeature(
                accessibilityFeatureClass: largestFeature.accessibilityFeatureClass,
                contourDetails: ContourDetails(
                    contourDetails: largestFeature.contourDetails, trapezoidPoints: trapezoidPoints
                )
            )
            detectedFeatures = [trapezoidFeature]
        }
        self.isProcessing = false
        return detectedFeatures
    }
}
