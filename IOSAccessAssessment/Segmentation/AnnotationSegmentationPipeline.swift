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
    
    init() {
        self.contourRequestProcessor = ContourRequestProcessor(
            contourEpsilon: self.contourEpsilon,
            perimeterThreshold: self.perimeterThreshold,
            selectionClassLabels: self.selectionClassLabels)
        self.homographyTransformFilter = HomographyTransformFilter()
        self.unionOfMasksProcessor = UnionOfMasksProcessor()
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
    
    func processTransformationsRequest(imageDataHistory: [ImageData]) -> [CIImage]? {
        if self.isProcessing {
            print("Unable to process Annotation-based segmentation. The AnnotationSegmentationPipeline is already processing a request.")
            return nil
        }
        guard let homographyTransformFilter = self.homographyTransformFilter else {
            print("Homography transform filter is not initialized.")
            return nil
        }
        
        self.isProcessing = true
        
        if imageDataHistory.count <= 1 {
            print("No image history available for processing.")
            self.isProcessing = false
            if imageDataHistory.count == 1 && imageDataHistory[0].segmentationLabelImage != nil {
                return [imageDataHistory[0].segmentationLabelImage!]
            }
            return nil
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
    
    func processUnionOfMasksRequest(targetValue: UInt8) -> AnnotationSegmentationPipelineResults? {
        if self.isProcessing {
            print("Unable to process Union of Masks. The AnnotationSegmentationPipeline is already processing a request.")
            return nil
        }
        self.isProcessing = true
        
        guard let unionOfMasksProcessor = self.unionOfMasksProcessor else {
            print("Union of masks processor is not initialized.")
            return nil
        }
        
        let unionImage = unionOfMasksProcessor.apply(targetValue: targetValue)
        guard unionImage != nil else {
            print("Failed to apply union of masks.")
            self.isProcessing = false
            return nil
        }
        self.contourRequestProcessor?.setSelectionClassLabels([targetValue])
        let objectList = self.contourRequestProcessor?.processRequest(from: unionImage!) ?? []
        
        self.isProcessing = false
        return AnnotationSegmentationPipelineResults(
            segmentationImage: unionImage!,
            detectedObjects: objectList
        )
    }
}
