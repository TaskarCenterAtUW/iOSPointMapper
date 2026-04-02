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

struct DamageDetectionResult {
    var boundingBox: CGRect
    var confidence: VNConfidence
    var label: String
}

struct DamageDetectionModelRequestProcessor {
    var visionModel: VNCoreMLModel
    
    init() throws {
        guard let modelURL = Constants.SurfaceIntegrityConstants.damageDetectionModelURL else {
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
