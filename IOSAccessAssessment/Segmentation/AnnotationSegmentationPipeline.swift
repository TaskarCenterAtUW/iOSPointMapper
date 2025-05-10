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
    var perimeterThreshold: Float = 0.01
    
    var contourRequestProcessor: ContourRequestProcessor?
    var homographyTransformFilter: HomographyTransformFilter?
    
    init() {
        self.contourRequestProcessor = ContourRequestProcessor(
            contourEpsilon: self.contourEpsilon,
            perimeterThreshold: self.perimeterThreshold,
            selectionClassLabels: self.selectionClassLabels)
        self.homographyTransformFilter = HomographyTransformFilter()
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
    
    func processRequest(imageDataHistory: [ImageData]) -> [CIImage]? {
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
        var transformMatrix: simd_float3x3 = matrix_identity_float3x3
        for i in (0..<imageDataHistory.count-1).reversed() {
            let currentImageData = imageDataHistory[i]
            let nextImageData = imageDataHistory[i+1]
            transformMatrix = (nextImageData.transformMatrixToNextFrame?.inverse ?? matrix_identity_float3x3) * transformMatrix
            if currentImageData.segmentationLabelImage == nil {
                continue
            }
            let buffer0 = CIImageUtils.toPixelBuffer(currentImageData.segmentationLabelImage!, pixelFormat: kCVPixelFormatType_OneComponent8)
            print("Unique grayscale values of original: \(CVPixelBufferUtils.extractUniqueGrayscaleValues(from: buffer0!))")
            // Apply the homography transform to the current image
            let transformedImage = homographyTransformFilter.apply(
                to: currentImageData.segmentationLabelImage!, transformMatrix: transformMatrix)
            if let transformedSegmentationLabelImage = transformedImage {
                let buffer = CIImageUtils.toPixelBuffer(transformedSegmentationLabelImage, pixelFormat: kCVPixelFormatType_OneComponent8)
                print("Unique grayscale values of transformed: \(CVPixelBufferUtils.extractUniqueGrayscaleValues(from: buffer!))")
                transformedSegmentationLabelImages.append(transformedSegmentationLabelImage)
            } else {
                print("Failed to apply homography transform to the image.")
            }
        }
        
        self.isProcessing = false
        return transformedSegmentationLabelImages
    }
}
