//
//  PlaneFitProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/24/26.
//

import simd
import Accelerate
import CoreImage

enum PlaneFitProcessorError: Error, LocalizedError {
    case initializationError(message: String)
    
    var errorDescription: String? {
        switch self {
        case .initializationError(let message):
            return "PlaneFit Initialization Error: \(message)"
        }
    }
}

struct PlaneFitProcessor {
    private let worldPointsProcessor: WorldPointsProcessor
    
    init() throws {
        self.worldPointsProcessor = try WorldPointsProcessor()
    }
    
    func fitPlanePCAWithImage(
        segmentationLabelImage: CIImage,
        depthImage: CIImage,
        targetValue: UInt8,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) throws {
        let worldPoints = try self.worldPointsProcessor.getWorldPoints(
            segmentationLabelImage: segmentationLabelImage, depthImage: depthImage,
            targetValue: targetValue, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
    }
}
