//
//  DamageDetectionAnnotationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/2/26.
//

import SwiftUI
import Combine
import Vision
import CoreML

public enum DamageDetectionPipelineError: Error, LocalizedError {
    case detectionResourcesNotConfigured
    
    public var errorDescription: String? {
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
public final class DamageDetectionPipeline: ObservableObject {
    private var damageDetectionModelRequestProcessor: DamageDetectionModelRequestProcessor?
    
    public func configure() throws {
        self.damageDetectionModelRequestProcessor = try DamageDetectionModelRequestProcessor()
    }
    
    public func processRequest(with cIImage: CIImage) throws -> [DamageDetectionResult] {
        guard let damageDetectionModelRequestProcessor = self.damageDetectionModelRequestProcessor else {
            throw DamageDetectionPipelineError.detectionResourcesNotConfigured
        }
        return try damageDetectionModelRequestProcessor.processDetectionRequest(with: cIImage)
    }
}
