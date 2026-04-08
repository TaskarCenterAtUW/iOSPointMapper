//
//  DamageDetectionModelRequestProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/2/26.
//

import CoreML
import Vision
import CoreImage

enum DamageDetectionModelError: Error, LocalizedError {
    case modelLoadingError
    case detectionProcessingError
    
    var errorDescription: String? {
        switch self {
        case .modelLoadingError:
            return "Failed to load the damage detection model."
        case .detectionProcessingError:
            return "An error occurred while processing the damage detection request."
        }
    }
}

/**
    This struct represents the result of a damage detection operation, containing the bounding box of the detected damage, the confidence score, and the label.
 
 - boundingBox: A CGRect representing the location and size of the detected damage in normalized coordinates (0 to 1). Here the origin is at the bottom-left corner of the image, and the width and height are relative to the image dimensions. Hence, to use it in pixel coordinates appropriately, the y-coordinate needs to be adjusted by subtracting the bounding box's height and y-origin from 1, and then scaling it according to the image size.
 - confidence: A VNConfidence value (between 0 and 1) indicating the confidence level of the detection.
 - label: A String representing the label or category of the detected damage.
 */
struct DamageDetectionResult: Sendable, Hashable {
    var boundingBox: CGRect
    var confidence: VNConfidence
    var label: String
    
    /// The bounding box returned by the model is in normalized coordinates (0 to 1) with the origin at the bottom-left corner.
    /// To convert it to pixel coordinates, we need to adjust the y-coordinate and scale it according to the image size.
    func getPixelCGRect(for imageSize: CGSize) -> CGRect {
        return CGRect(
            x: CGFloat(boundingBox.origin.x) * imageSize.width,
            y: CGFloat(1.0 - boundingBox.origin.y - boundingBox.size.height) * imageSize.height,
            width: CGFloat(boundingBox.size.width) * imageSize.width,
            height: CGFloat(boundingBox.size.height) * imageSize.height
        )
    }
}

/**
 This class is responsible for loading the damage detection model and processing detection requests.
 
 The Damage Detection model returns bounding boxes, that through coreml post-processing, returns each bounding box in the following format:
 - CGRect: (x, y, width, height) in normalized coordinates (0 to 1), where x and y represent the bottom-left corner of the bounding box relative to the image dimensions.
 - Confidence Score: A value between 0 and 1 indicating the confidence level of the detection
 */
struct DamageDetectionModelRequestProcessor {
    var visionModel: VNCoreMLModel
    
    init() throws {
        guard let modelURL = Constants.DamageDetectionConstants.damageDetectionModelURL else {
            throw DamageDetectionModelError.modelLoadingError
        }
        let configuration: MLModelConfiguration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        self.visionModel = try VNCoreMLModel(for: MLModel(contentsOf: modelURL, configuration: configuration))
    }
    
    private func configureSegmentationRequest(request: VNCoreMLRequest) {
        // TODO: Need to check on the ideal options for this
        request.imageCropAndScaleOption = .scaleFill
    }
    
    func processDetectionRequest(
        with cIImage: CIImage, orientation: CGImagePropertyOrientation = .up
    ) throws -> [DamageDetectionResult] {
        let detectionRequest = VNCoreMLRequest(model: self.visionModel)
        self.configureSegmentationRequest(request: detectionRequest)
        let detectionRequestHandler = VNImageRequestHandler(ciImage: cIImage, orientation: orientation, options: [:])
        try detectionRequestHandler.perform([detectionRequest])
        
        guard let results = detectionRequest.results as? [VNRecognizedObjectObservation] else {
            throw DamageDetectionModelError.detectionProcessingError
        }
        let damageDetectionResults = results.map { observation in
            let topLabel = observation.labels.first
            return DamageDetectionResult(
                boundingBox: observation.boundingBox,
                confidence: topLabel?.confidence ?? 0.0,
                label: topLabel?.identifier ?? "N/A"
            )
        }
        return damageDetectionResults
    }
}
