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
            return "The Segmentation Image Pipeline is already processing a request."
        case .emptySegmentation:
            return "The Segmentation array is Empty"
        case .invalidSegmentation:
            return "The Segmentation is invalid"
        case .invalidContour:
            return "The Contour is invalid"
        case .invalidTransform:
            return "The Homography Transform is invalid"
        case .unexpectedError:
            return "An unexpected error occurred in the Segmentation Image Pipeline."
        }
    }
}

struct SegmentationARPipelineResults {
    var segmentationImage: CIImage
    var segmentationColorImage: CIImage
    var segmentedIndices: [Int]
    var detectedObjectMap: [UUID: DetectedObject]
    var transformMatrixFromPreviousFrame: simd_float3x3? = nil
    
    init(segmentationImage: CIImage, segmentationColorImage: CIImage, segmentedIndices: [Int],
         detectedObjectMap: [UUID: DetectedObject]) {
        self.segmentationImage = segmentationImage
        self.segmentationColorImage = segmentationColorImage
        self.segmentedIndices = segmentedIndices
        self.detectedObjectMap = detectedObjectMap
    }
}

/**
    A class to handle segmentation as well as the post-processing of the segmentation results on demand.
 
    TODO: Rename this to `SegmentationImagePipeline` since AR is not a necessary component here.
 */
final class SegmentationARPipeline: ObservableObject {
    private var isProcessing = false
    private var currentTask: Task<SegmentationARPipelineResults, Error>?
    private var timeoutInSeconds: Double = 1.0
    
    private var selectionClasses: [Int] = []
    private var selectionClassLabels: [UInt8] = []
    private var selectionClassGrayscaleValues: [Float] = []
    private var selectionClassColors: [CIColor] = []
    
    // TODO: Check what would be the appropriate value for this
    private var contourEpsilon: Float = 0.01
    // TODO: Check what would be the appropriate value for this
    // For normalized points
    private var perimeterThreshold: Float = 0.01
    
    private var grayscaleToColorMasker: GrayscaleToColorFilter?
    private var segmentationModelRequestProcessor: SegmentationModelRequestProcessor?
    private var contourRequestProcessor: ContourRequestProcessor?
    
    init() {
        
    }
    
    func configure() throws {
        self.segmentationModelRequestProcessor = try SegmentationModelRequestProcessor(
            selectionClasses: self.selectionClasses)
        self.contourRequestProcessor = try ContourRequestProcessor(
            contourEpsilon: self.contourEpsilon,
            perimeterThreshold: self.perimeterThreshold,
            selectionClassLabels: self.selectionClassLabels)
        self.grayscaleToColorMasker = try GrayscaleToColorFilter()
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
    func processRequest(with cIImage: CIImage, highPriority: Bool = false) async throws -> SegmentationARPipelineResults {
        if (highPriority) {
            self.currentTask?.cancel()
        } else {
            if ((currentTask != nil) && !currentTask!.isCancelled) {
                throw SegmentationARPipelineError.isProcessingTrue
            }
        }
        
        let newTask = Task { [weak self] () throws -> SegmentationARPipelineResults in
            guard let self = self else { throw SegmentationARPipelineError.unexpectedError }
            defer {
                self.currentTask = nil
            }
            try Task.checkCancellation()
            
            let results = try await self.processImageWithTimeout(cIImage)
            try Task.checkCancellation()
            return results
        }
        
        self.currentTask = newTask
        return try await newTask.value
    }
    
    private func processImageWithTimeout(_ cIImage: CIImage) async throws -> SegmentationARPipelineResults {
        try await withThrowingTaskGroup(of: SegmentationARPipelineResults.self) { group in
            group.addTask {
                return try self.processImage(cIImage)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeoutInSeconds))
                throw SegmentationARPipelineError.unexpectedError
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
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
     3. Return the segmentation image, segmented indices, and detected objects, to the caller function
     
     Since this function can be called within a Task, it checks for cancellation at various points to ensure that it can exit early if needed.
     */
    private func processImage(_ cIImage: CIImage) throws -> SegmentationARPipelineResults {
        let segmentationResults = try self.segmentationModelRequestProcessor?.processSegmentationRequest(with: cIImage)
        guard let segmentationImage = segmentationResults?.segmentationImage else {
            throw SegmentationARPipelineError.invalidSegmentation
        }
        
        try Task.checkCancellation()
        
        // MARK: Ignoring the contour detection and object tracking for now
        // Get the objects from the segmentation image
        let detectedObjects: [DetectedObject] = try self.contourRequestProcessor?.processRequest(from: segmentationImage) ?? []
        // MARK: The temporary UUIDs can be removed if we do not need to track objects across frames
        let detectedObjectMap: [UUID: DetectedObject] = Dictionary(uniqueKeysWithValues: detectedObjects.map { (UUID(), $0) })
        
        try Task.checkCancellation()
        
        guard let segmentationColorImage = try self.grayscaleToColorMasker?.apply(
            to: segmentationImage, grayscaleValues: self.selectionClassGrayscaleValues, colorValues: self.selectionClassColors
        ) else {
            throw SegmentationARPipelineError.invalidSegmentation
        }
//        let segmentationResultUIImage = UIImage(
//            ciImage: self.grayscaleToColorMasker.outputImage!,
//            scale: 1.0, orientation: .up) // Orientation is handled in processSegmentationRequest
        
        return SegmentationARPipelineResults(
            segmentationImage: segmentationImage,
            segmentationColorImage: segmentationColorImage,
            segmentedIndices: segmentationResults?.segmentedIndices ?? [],
            detectedObjectMap: detectedObjectMap
        )
    }
    
}
