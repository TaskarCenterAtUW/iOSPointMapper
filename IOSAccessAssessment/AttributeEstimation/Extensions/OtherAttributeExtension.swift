//
//  OtherAttributeExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/25/26.
//
import SwiftUI
import CoreLocation

/**
 Extension for attribute calculation with rudimentary methods.
 TODO: Improve upon these methods with more robust implementations.
 */
extension AttributeEstimationPipeline {
    /**
     Intermediary method to calculate the plane of the feature.
     */
    func calculatePlane(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> Plane {
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.depthMapProcessorKey)
        }
        guard let planeFitProcesor = self.planeFitProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeFitProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        
        let plane = try planeFitProcesor.fitPlanePCAWithImage(
            segmentationLabelImage: captureImageData.captureImageDataResults.segmentationLabelImage,
            depthImage: depthMapProcessor.depthImage,
            targetValue: accessibilityFeature.accessibilityFeatureClass.labelValue,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics
        )
        return plane
    }
    
    func calculateWidth(
        accessibilityFeature: EditableAccessibilityFeature,
        plane: Plane? = nil
    ) throws -> AccessibilityFeatureAttribute.Value {
        var plane = try (plane ?? calculatePlane(accessibilityFeature: accessibilityFeature))
        
        guard let widthAttributeValue = AccessibilityFeatureAttribute.width.valueFromDouble(Double(0)) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return widthAttributeValue
    }
    
    func calculateRunningSlope(
        accessibilityFeature: EditableAccessibilityFeature,
        plane: Plane? = nil
    ) throws -> AccessibilityFeatureAttribute.Value {
        var plane = try (plane ?? calculatePlane(accessibilityFeature: accessibilityFeature))
        
        guard let runningSlopeAttributeValue = AccessibilityFeatureAttribute.runningSlope.valueFromDouble(0) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return runningSlopeAttributeValue
    }
    
    func calculateCrossSlope(
        accessibilityFeature: EditableAccessibilityFeature,
        plane: Plane? = nil
    ) throws -> AccessibilityFeatureAttribute.Value {
        var plane = try (plane ?? calculatePlane(accessibilityFeature: accessibilityFeature))
        
        guard let crossSlopeAttributeValue = AccessibilityFeatureAttribute.crossSlope.valueFromDouble(0) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return crossSlopeAttributeValue
    }
}
