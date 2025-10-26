//
//  SegmentationARPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/17/25.
//

import SwiftUI
import Vision
import CoreML

import OrderedCollections
import simd

enum SegmentationARPipelineError: Error, LocalizedError {
    case isProcessingTrue
    case emptySegmentation
    case invalidSegmentation
    case invalidContour
    case invalidTransform
    case unexpectedError
    
    var errorDescription: String? {
        switch self {
        case .isProcessingTrue:
            return "The SegmentationPipeline is already processing a request."
        case .emptySegmentation:
            return "The Segmentation array is Empty"
        case .invalidSegmentation:
            return "The Segmentation is invalid"
        case .invalidContour:
            return "The Contour is invalid"
        case .invalidTransform:
            return "The Homography Transform is invalid"
        case .unexpectedError:
            return "An unexpected error occurred in the SegmentationARPipeline."
        }
    }
}

struct SegmentationARPipelineResults {
    var segmentationImage: CIImage
    var segmentationResultUIImage: UIImage
    var segmentedIndices: [Int]
    var detectedObjectMap: [UUID: DetectedObject]
    var transformMatrixFromPreviousFrame: simd_float3x3? = nil
    // TODO: Have some kind of type-safe payload for additional data to make it easier to use
    var additionalPayload: [String: Any] = [:] // This can be used to pass additional data if needed
    
    init(segmentationImage: CIImage, segmentationResultUIImage: UIImage, segmentedIndices: [Int],
         detectedObjectMap: [UUID: DetectedObject],
         additionalPayload: [String: Any] = [:]) {
        self.segmentationImage = segmentationImage
        self.segmentationResultUIImage = segmentationResultUIImage
        self.segmentedIndices = segmentedIndices
        self.detectedObjectMap = detectedObjectMap
        self.additionalPayload = additionalPayload
    }
}

/**
    A class to handle segmentation as well as the post-processing of the segmentation results on demand.
    Currently, a giant monolithic class that handles all the requests. Will be refactored in the future to divide the request types into separate classes.
 */
final class SegmentationARPipeline: ObservableObject {
    // TODO: Update this to multiple states (one for each of segmentation, contour detection, etc.)
    //  to pipeline the processing.
    //  This will help in more efficiently batching the requests, but will also be quite complex to handle.
    private var isProcessing = false
    
    var selectionClasses: [Int] = []
    var selectionClassLabels: [UInt8] = []
    var selectionClassGrayscaleValues: [Float] = []
    var selectionClassColors: [CIColor] = []
    
    // TODO: Check what would be the appropriate value for this
    var contourEpsilon: Float = 0.01
    // TODO: Check what would be the appropriate value for this
    // For normalized points
    var perimeterThreshold: Float = 0.01
    
    let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    var segmentationModelRequestProcessor: SegmentationModelRequestProcessor?
    var contourRequestProcessor: ContourRequestProcessor?
    
    init() {
        self.segmentationModelRequestProcessor = SegmentationModelRequestProcessor(
            selectionClasses: self.selectionClasses)
        self.contourRequestProcessor = ContourRequestProcessor(
            contourEpsilon: self.contourEpsilon,
            perimeterThreshold: self.perimeterThreshold,
            selectionClassLabels: self.selectionClassLabels)
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
        
        self.segmentationModelRequestProcessor?.setSelectionClasses(self.selectionClasses)
        self.contourRequestProcessor?.setSelectionClassLabels(self.selectionClassLabels)
    }
    
    /**
        Function to process the segmentation request with the given CIImage.
     */
    func processRequest(with cIImage: CIImage, highPriority: Bool = false) {
        if (self.isProcessing && !highPriority) {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            if highPriority {
                while self.isProcessing {
                    Thread.sleep(forTimeInterval: 0.01) // Sleep for a short duration to avoid busy waiting
                }
            }
            self.isProcessing = true
            
            do {
                let processedImageResults = try self.processImage(cIImage)
                return
//                SegmentationARPipelineResults(
//                    segmentationImage: processedImageResults.segmentationImage,
//                    segmentationResultUIImage: processedImageResults.segmentationResultUIImage,
//                    segmentedIndices: processedImageResults.segmentedIndices,
//                    detectedObjectMap: processedImageResults.detectedObjectMap
//                )
            } catch let error as SegmentationARPipelineError {
                return
            } catch {
                return
            }
            self.isProcessing = false
        }
    }
    
    /**
     Function to process the given CIImage.
     This function will perform the processing within the thread in which it is called.
     It does not check if the pipeline is already processing a request, or even look for the completion handler.
     It will either return the SegmentationARPipelineResults or throw an error.
     
     The entire procedure has the following main steps:
     1. Get the segmentation mask from the camera image using the segmentation model
     2. Get the objects from the segmentation image
     5. Return the segmentation image, segmented indices, and detected objects, to the caller function
     */
    func processImage(_ cIImage: CIImage) throws -> SegmentationARPipelineResults {
        let segmentationResults = self.segmentationModelRequestProcessor?.processSegmentationRequest(with: cIImage) ?? nil
        guard let segmentationImage = segmentationResults?.segmentationImage else {
            throw SegmentationARPipelineError.invalidSegmentation
        }
        
        // MARK: Ignoring the contour detection and object tracking for now
        // Get the objects from the segmentation image
        let detectedObjects = self.contourRequestProcessor?.processRequest(from: segmentationImage) ?? []
        // MARK: The temporary UUIDs can be removed if we do not need to track objects across frames
        let detectedObjectMap: [UUID: DetectedObject] = Dictionary(uniqueKeysWithValues: detectedObjects.map { (UUID(), $0) })
        
        self.grayscaleToColorMasker.inputImage = segmentationImage
        self.grayscaleToColorMasker.grayscaleValues = self.selectionClassGrayscaleValues
        self.grayscaleToColorMasker.colorValues =  self.selectionClassColors
        let segmentationResultUIImage = UIImage(
            ciImage: self.grayscaleToColorMasker.outputImage!,
            scale: 1.0, orientation: .up) // Orientation is handled in processSegmentationRequest
        
        return SegmentationARPipelineResults(
            segmentationImage: segmentationImage,
            segmentationResultUIImage: segmentationResultUIImage,
            segmentedIndices: segmentationResults?.segmentedIndices ?? [],
            detectedObjectMap: detectedObjectMap
        )
    }
    
}
