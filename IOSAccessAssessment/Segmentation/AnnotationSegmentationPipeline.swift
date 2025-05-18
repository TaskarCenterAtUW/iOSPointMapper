//
//  AnnotationSegmentationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/10/25.
//

import SwiftUI
import Vision
import CoreML

import OrderedCollections
import simd

enum AnnotationSegmentationPipelineError: Error, LocalizedError {
    case isProcessingTrue
    case homographyTransformFilterNil
    case imageHistoryEmpty
    case unionOfMasksProcessorNil
    case contourRequestProcessorNil
    case invalidUnionImageResult
    
    var errorDescription: String? {
        switch self {
        case .isProcessingTrue:
            return "The AnnotationSegmentationPipeline is already processing a request."
        case .homographyTransformFilterNil:
            return "Homography transform filter is not initialized."
        case .imageHistoryEmpty:
            return "Image data history is empty."
        case .unionOfMasksProcessorNil:
            return "Union of masks processor is not initialized."
        case .contourRequestProcessorNil:
            return "Contour request processor is not initialized."
        case .invalidUnionImageResult:
            return "Failed to apply union of masks."
        }
    }
}
    

struct AnnotationSegmentationPipelineResults {
    var segmentationImage: CIImage
    var detectedObjects: [DetectedObject]
    
    init(segmentationImage: CIImage, detectedObjects: [DetectedObject]) {
        self.segmentationImage = segmentationImage
        self.detectedObjects = detectedObjects
    }
}

/**
 A class to handle the segmentation pipeline for annotation purposes.
 Unlike the main SegmentationPipeline, this class processes images and returns the results synchronously.
 Later, we can consider making it asynchronous based on the requirements.
 */
class AnnotationSegmentationPipeline {
    // This will be useful only when we are using the pipeline in asynchronous mode.
    var isProcessing = false
    
    var selectionClasses: [Int] = []
    var selectionClassLabels: [UInt8] = []
    var selectionClassGrayscaleValues: [Float] = []
    var selectionClassColors: [CIColor] = []
    
    // TODO: Check what would be the appropriate value for this
    var contourEpsilon: Float = 0.01
    // TODO: Check what would be the appropriate value for this
    // For normalized points
    var perimeterThreshold: Float = 0.2
    
    var contourRequestProcessor: ContourRequestProcessor?
    var homographyTransformFilter: HomographyTransformFilter?
    var unionOfMasksProcessor: UnionOfMasksProcessor?
    var dimensionBasedMaskFilter: DimensionBasedMaskFilter?
    
    init() {
        self.contourRequestProcessor = ContourRequestProcessor(
            contourEpsilon: self.contourEpsilon,
            perimeterThreshold: self.perimeterThreshold,
            selectionClassLabels: self.selectionClassLabels)
        self.homographyTransformFilter = HomographyTransformFilter()
        self.unionOfMasksProcessor = UnionOfMasksProcessor()
        self.dimensionBasedMaskFilter = DimensionBasedMaskFilter()
    }
    
    func reset() {
        self.isProcessing = false
        self.setSelectionClasses([])
    }
    
    func setSelectionClasses(_ selectionClasses: [Int]) {
        self.selectionClasses = selectionClasses
        self.selectionClassLabels = selectionClasses.map { Constants.ClassConstants.labels[$0] }
        self.selectionClassGrayscaleValues = selectionClasses.map { Constants.ClassConstants.grayscaleValues[$0] }
        self.selectionClassColors = selectionClasses.map { Constants.ClassConstants.colors[$0] }
        
        self.contourRequestProcessor?.setSelectionClassLabels(self.selectionClassLabels)
    }
    
    func processTransformationsRequest(imageDataHistory: [ImageData]) throws -> [CIImage] {
        if self.isProcessing {
            throw AnnotationSegmentationPipelineError.isProcessingTrue
        }
        guard let homographyTransformFilter = self.homographyTransformFilter else {
            throw AnnotationSegmentationPipelineError.homographyTransformFilterNil
        }
        
        self.isProcessing = true
        
        if imageDataHistory.count <= 1 {
            print("No image history available for processing.")
            self.isProcessing = false
            if imageDataHistory.count == 1 && imageDataHistory[0].segmentationLabelImage != nil {
                return [imageDataHistory[0].segmentationLabelImage!]
            }
            throw AnnotationSegmentationPipelineError.imageHistoryEmpty
        }
        var transformedSegmentationLabelImages: [CIImage] = []
        
        /**
         Iterate through the image data history in reverse.
         Process each image by applying the homography transforms of the successive images.
         */
        // Identity matrix for the first image
        var transformMatrixToNextFrame: simd_float3x3 = matrix_identity_float3x3
        for i in (0..<imageDataHistory.count).reversed() {
            let currentImageData = imageDataHistory[i]
            if currentImageData.segmentationLabelImage == nil {
                transformMatrixToNextFrame = (
                    currentImageData.transformMatrixToPreviousFrame?.inverse ?? matrix_identity_float3x3
                ) * transformMatrixToNextFrame
                continue
            }
            // Apply the homography transform to the current image
            let transformedImage = homographyTransformFilter.apply(
                to: currentImageData.segmentationLabelImage!, transformMatrix: transformMatrixToNextFrame)
            transformMatrixToNextFrame = (
                currentImageData.transformMatrixToPreviousFrame?.inverse ?? matrix_identity_float3x3
            ) * transformMatrixToNextFrame
            if let transformedSegmentationLabelImage = transformedImage {
                transformedSegmentationLabelImages.append(transformedSegmentationLabelImage)
            } else {
                print("Failed to apply homography transform to the image.")
            }
        }
        
        self.isProcessing = false
        return transformedSegmentationLabelImages
    }
    
    func setupUnionOfMasksRequest(segmentationLabelImages: [CIImage]) {
        self.unionOfMasksProcessor?.setArrayTexture(images: segmentationLabelImages)
    }
    
    func processUnionOfMasksRequest(targetValue: UInt8) throws -> CIImage {
        if self.isProcessing {
            throw AnnotationSegmentationPipelineError.isProcessingTrue
        }
        self.isProcessing = true
        
        guard let unionOfMasksProcessor = self.unionOfMasksProcessor else {
            throw AnnotationSegmentationPipelineError.unionOfMasksProcessorNil
        }
        
        let unionImageResult = unionOfMasksProcessor.apply(targetValue: targetValue)
        guard var unionImage = unionImageResult else {
            self.isProcessing = false
            throw AnnotationSegmentationPipelineError.invalidUnionImageResult
        }
        
        self.isProcessing = false
        return unionImage
    }
    
    func processContourRequest(from ciImage: CIImage, targetValue: UInt8, isWay: Bool = false,
                               bounds: DimensionBasedMaskBounds? = nil) throws -> [DetectedObject] {
        if self.isProcessing {
            throw AnnotationSegmentationPipelineError.isProcessingTrue
        }
        self.isProcessing = true
        
        guard let contourRequestProcessor = self.contourRequestProcessor else {
            throw AnnotationSegmentationPipelineError.contourRequestProcessorNil
        }
        
        self.contourRequestProcessor?.setSelectionClassLabels([targetValue])
        var detectedObjects = self.contourRequestProcessor?.processRequest(from: ciImage) ?? []
        if isWay && bounds != nil {
            var largestObject = detectedObjects.sorted(by: {$0.perimeter > $1.perimeter}).first
            if largestObject != nil {
                let bounds = self.contourRequestProcessor?.getContourTrapezoid(from: largestObject?.normalizedPoints ?? [])
                largestObject?.wayBounds = bounds
                detectedObjects = [largestObject!]
            }
        }
        
        self.isProcessing = false
        return detectedObjects
    }
        
}
