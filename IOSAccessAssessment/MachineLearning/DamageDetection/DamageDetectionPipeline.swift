//
//  DamageDetectionAnnotationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/2/26.
//

import SwiftUI
import Vision
import CoreML

enum DamageDetectionPipelineError: Error, LocalizedError {
    case detectionResourcesNotConfigured
    
    var errorDescription: String? {
        switch self {
        case .detectionResourcesNotConfigured:
            return "The Detection Image Pipeline resources are not configured"
        }
    }
    
}

/**
 This class serves as the main interface for processing damage detection requests.
 In the future, it can include logic for asynchronous processing, request queuing, and more. 
 */
final class DamageDetectionPipeline: ObservableObject {
    private var damageDetectionModelRequestProcessor: DamageDetectionModelRequestProcessor?
    
    func configure() throws {
        self.damageDetectionModelRequestProcessor = try DamageDetectionModelRequestProcessor()
    }
    
    func processRequest(with cIImage: CIImage) throws -> [DamageDetectionResult] {
        guard let damageDetectionModelRequestProcessor = self.damageDetectionModelRequestProcessor else {
            throw DamageDetectionPipelineError.detectionResourcesNotConfigured
        }
        return try damageDetectionModelRequestProcessor.processDetectionRequest(with: cIImage)
    }
}
