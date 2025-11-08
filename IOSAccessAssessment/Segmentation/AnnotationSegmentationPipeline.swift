//
//  AnnotationSegmentationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/10/25.
//

import SwiftUI
import Vision

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
    let context = CIContext()
    
    init() {
        do {
            self.contourRequestProcessor = try ContourRequestProcessor(
                contourEpsilon: self.contourEpsilon,
                perimeterThreshold: self.perimeterThreshold,
                selectionClassLabels: self.selectionClassLabels)
            self.homographyTransformFilter = try HomographyTransformFilter()
            self.dimensionBasedMaskFilter = try DimensionBasedMaskFilter()
        } catch {
            print("Error initializing AnnotationSegmentationPipeline: \(error)")
        }
        self.unionOfMasksProcessor = UnionOfMasksProcessor()
    }
    
    func reset() {
        self.isProcessing = false
        self.setSelectionClasses([])
    }
    
    func setSelectionClasses(_ selectionClasses: [Int]) {
        self.selectionClasses = selectionClasses
        self.selectionClassLabels = selectionClasses.map { Constants.SelectedSegmentationConfig.labels[$0] }
        self.selectionClassGrayscaleValues = selectionClasses.map { Constants.SelectedSegmentationConfig.grayscaleValues[$0] }
        self.selectionClassColors = selectionClasses.map { Constants.SelectedSegmentationConfig.colors[$0] }
        
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
         
         TODO: Need to check if the error handling is appropriate here.
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
            transformMatrixToNextFrame = (
                currentImageData.transformMatrixToPreviousFrame?.inverse ?? matrix_identity_float3x3
            ) * transformMatrixToNextFrame
            // Apply the homography transform to the current image
            var transformedImage: CIImage
            do {
                transformedImage = try homographyTransformFilter.apply(
                    to: currentImageData.segmentationLabelImage!, transformMatrix: transformMatrixToNextFrame)
            } catch {
                print("Error applying homography transform: \(error)")
                continue
            }
            transformedSegmentationLabelImages.append(transformedImage)
        }
        
        self.isProcessing = false
        return transformedSegmentationLabelImages
    }
    
    func setupUnionOfMasksRequest(segmentationLabelImages: [CIImage]) {
        self.unionOfMasksProcessor?.setArrayTexture(images: segmentationLabelImages)
    }
    
    func processUnionOfMasksRequest(targetValue: UInt8, bounds: DimensionBasedMaskBounds? = nil,
                                    unionOfMasksThreshold: Float = 1.0,
                                    defaultFrameWeight: Float = 1.0, lastFrameWeight: Float = 1.0) throws -> CIImage {
        if self.isProcessing {
            throw AnnotationSegmentationPipelineError.isProcessingTrue
        }
        self.isProcessing = true
        
        guard let unionOfMasksProcessor = self.unionOfMasksProcessor else {
            throw AnnotationSegmentationPipelineError.unionOfMasksProcessorNil
        }
        
        let unionImageResult = unionOfMasksProcessor.apply(targetValue: targetValue,
                                                           unionOfMasksThreshold: unionOfMasksThreshold,
                                                           defaultFrameWeight: defaultFrameWeight,
                                                           lastFrameWeight: lastFrameWeight)
        guard var unionImage = unionImageResult else {
            self.isProcessing = false
            throw AnnotationSegmentationPipelineError.invalidUnionImageResult
        }
        
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
    
    func processContourRequest(from ciImage: CIImage, targetValue: UInt8, isWay: Bool = false,
                               bounds: DimensionBasedMaskBounds? = nil) throws -> [DetectedObject] {
        if self.isProcessing {
            throw AnnotationSegmentationPipelineError.isProcessingTrue
        }
        self.isProcessing = true
        
        guard self.contourRequestProcessor != nil else {
            throw AnnotationSegmentationPipelineError.contourRequestProcessorNil
        }
        
        self.contourRequestProcessor?.setSelectionClassLabels([targetValue])
        var detectedObjects = try self.contourRequestProcessor?.processRequest(from: ciImage) ?? []
        if isWay && bounds != nil {
            let largestObject = detectedObjects.sorted(by: {$0.perimeter > $1.perimeter}).first
            if largestObject != nil {
                let wayBounds = self.contourRequestProcessor?.getContourTrapezoid(from: largestObject?.normalizedPoints ?? [])
                largestObject?.wayBounds = wayBounds
                detectedObjects = [largestObject!]
            }
        }
        
        self.isProcessing = false
        return detectedObjects
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
