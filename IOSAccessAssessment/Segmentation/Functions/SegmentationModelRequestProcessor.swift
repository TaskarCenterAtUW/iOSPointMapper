//
//  SegmentationModelRequestProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/5/25.
//
import CoreML
import Vision

struct SegmentationModelRequestProcessor {
    var visionModel: VNCoreMLModel
    
    var selectionClasses: [Int] = []
    
    init(selectionClasses: [Int]) {
        let modelURL = Bundle.main.url(forResource: "espnetv2_pascal_256", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Cannot load CNN model")
        }
        self.visionModel = visionModel
        self.selectionClasses = selectionClasses
    }
    
    mutating func setSelectionClasses(_ classes: [Int]) {
        self.selectionClasses = classes
    }
    
    private func configureSegmentationRequest(request: VNCoreMLRequest) {
        // TODO: Need to check on the ideal options for this
        request.imageCropAndScaleOption = .scaleFill
    }
    
    // MARK: Currently we are relying on the synchronous nature of the request handler
    // Need to check if this is always guaranteed.
    func processSegmentationRequest(with cIImage: CIImage, orientation: CGImagePropertyOrientation = .up)
    -> (segmentationImage: CIImage, segmentedIndices: [Int])? {
        do {
            let segmentationRequest = VNCoreMLRequest(model: self.visionModel)
            self.configureSegmentationRequest(request: segmentationRequest)
            let segmentationRequestHandler = VNImageRequestHandler(
                ciImage: cIImage,
                orientation: orientation,
                options: [:])
            try segmentationRequestHandler.perform([segmentationRequest])
            
            guard let segmentationResult = segmentationRequest.results as? [VNPixelBufferObservation] else {return nil}
            let segmentationBuffer = segmentationResult.first?.pixelBuffer
            
            let (_, selectedIndices) = extractUniqueGrayscaleValues(from: segmentationBuffer!)
            let selectedIndicesSet = Set(selectedIndices)
            let segmentedIndices = self.selectionClasses.filter{ selectedIndicesSet.contains($0) }
            
            let segmentationImage = CIImage(cvPixelBuffer: segmentationBuffer!)
            
            return (segmentationImage: segmentationImage, segmentedIndices: segmentedIndices)
        } catch {
            print("Error processing segmentation request: \(error)")
        }
        return nil
    }
}
