//
//  SegmentationModelRequestProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/5/25.
//
import CoreML
import Vision
import CoreImage

enum SegmentationModelError: Error, LocalizedError {
    case modelLoadingError
    case segmentationProcessingError
    
    var errorDescription: String? {
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
struct SegmentationModelRequestProcessor {
    var visionModel: VNCoreMLModel
    
    var selectionClasses: [Int] = []
    
    init(selectionClasses: [Int]) throws {
        let modelURL = Constants.SelectedSegmentationConfig.modelURL
        let configuration: MLModelConfiguration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        self.visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL!, configuration: configuration))
        self.selectionClasses = selectionClasses
    }
    
    mutating func setSelectionClasses(_ classes: [Int]) {
        self.selectionClasses = classes
    }
    
    private func configureSegmentationRequest(request: VNCoreMLRequest) {
        // TODO: Need to check on the ideal options for this
        request.imageCropAndScaleOption = .scaleFill
    }
    
    func processSegmentationRequest(
        with cIImage: CIImage, orientation: CGImagePropertyOrientation = .up
    ) throws -> (segmentationImage: CIImage, segmentedIndices: [Int]) {
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
        let segmentationBuffer = segmentationResult.first?.pixelBuffer
        
        let uniqueGrayScaleValues = CVPixelBufferUtils.extractUniqueGrayscaleValues(from: segmentationBuffer!)
        let grayscaleValuesToIndex = Constants.SelectedSegmentationConfig.labelToIndexMap
        let selectedIndices = uniqueGrayScaleValues.compactMap { grayscaleValuesToIndex[$0] }
        let selectedIndicesSet = Set(selectedIndices)
        let segmentedIndices = self.selectionClasses.filter{ selectedIndicesSet.contains($0) }
        
        let segmentationImage = CIImage(cvPixelBuffer: segmentationBuffer!)
        
        return (segmentationImage: segmentationImage, segmentedIndices: segmentedIndices)
    }
}
