//
//  SegmentationModelRequestProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/5/25.
//
import CoreML
import Vision
import CoreImage
import PointNMapShared

public enum SegmentationModelError: Error, LocalizedError {
    case modelLoadingError
    case segmentationProcessingError
    
    public var errorDescription: String? {
        switch self {
        case .modelLoadingError:
            return "Failed to load the segmentation model."
        case .segmentationProcessingError:
            return "Error occurred while processing the segmentation request."
        }
    }
}

/**
    A struct to handle the segmentation model request processing.
    Processes the segmentation model request and returns the segmentation mask as well as the segmented indices.
 */
public struct SegmentationModelRequestProcessor {
    public var visionModel: VNCoreMLModel
    
    public var selectedClasses: [AccessibilityFeatureClass] = []
    
    public init(selectedClasses: [AccessibilityFeatureClass]) throws {
        guard let modelURL = SharedAppConstants.SelectedAccessibilityFeatureConfig.modelURL else {
            throw SegmentationModelError.modelLoadingError
        }
        let configuration: MLModelConfiguration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        self.visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL, configuration: configuration))
        self.selectedClasses = selectedClasses
    }
    
    public mutating func setSelectedClasses(_ classes: [AccessibilityFeatureClass]) {
        self.selectedClasses = classes
    }
    
    private func configureSegmentationRequest(request: VNCoreMLRequest) {
        // TODO: Need to check on the ideal options for this
        request.imageCropAndScaleOption = .scaleFill
    }
    
    public func processSegmentationRequest(
        with cIImage: CIImage, orientation: CGImagePropertyOrientation = .up
    ) throws -> (segmentationImage: CIImage, segmentedClasses: [AccessibilityFeatureClass]) {
        let segmentationRequest = VNCoreMLRequest(model: self.visionModel)
        self.configureSegmentationRequest(request: segmentationRequest)
        let segmentationRequestHandler = VNImageRequestHandler(
            ciImage: cIImage,
            orientation: orientation,
            options: [:])
        try segmentationRequestHandler.perform([segmentationRequest])
        
        guard let segmentationResult = segmentationRequest.results as? [VNPixelBufferObservation] else {
            throw SegmentationModelError.segmentationProcessingError
        }
        guard let segmentationBuffer = segmentationResult.first?.pixelBuffer else {
            throw SegmentationModelError.segmentationProcessingError
        }
        
        let uniqueGrayScaleValues = CVPixelBufferUtils.extractUniqueGrayscaleValues(from: segmentationBuffer)
        
        let grayscaleValuesToClassMap = SharedAppConstants.SelectedAccessibilityFeatureConfig.labelToClassMap
        var segmentedClasses = uniqueGrayScaleValues.compactMap { grayscaleValuesToClassMap[$0] }
        let segmentedClassSet = Set(segmentedClasses)
        segmentedClasses = self.selectedClasses.filter{ segmentedClassSet.contains($0) }
        
        let segmentationImage = CIImage(cvPixelBuffer: segmentationBuffer)
        
        return (segmentationImage: segmentationImage, segmentedClasses: segmentedClasses)
    }
}
