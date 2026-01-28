//
//  OtherAttributeExtensionLegacy.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/25/26.
//
import SwiftUI
import CoreLocation

/**
 Extension for attribute calculation with rudimentary methods.
 TODO: Improve upon these methods with more robust implementations.
 
 NOTE: Legacy Implementation. Needs to be improved.
 */
extension AttributeEstimationPipeline {
    func calculateWidthLegacy(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.depthMapProcessorKey)
        }
        guard let localizationProcessor = self.localizationProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.localizationProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let trapezoidBoundPoints = accessibilityFeature.contourDetails.trapezoidPoints,
              trapezoidBoundPoints.count == 4 else {
            throw AttributeEstimationPipelineError.invalidAttributeData
        }
        let trapezoidBoundDepthValues = try depthMapProcessor.getFeatureDepthsAtBounds(
            detectedFeature: accessibilityFeature
        )
        let trapezoidBoundPointsWithDepth: [PointWithDepth] = zip(trapezoidBoundPoints, trapezoidBoundDepthValues).map {
            PointWithDepth(
                point: CGPoint(x: CGFloat($0.0.x), y: CGFloat($0.0.y)),
                depth: $0.1
            )
        }
        let widthValue = try localizationProcessor.calculateWidth(
            trapezoidBoundsWithDepth: trapezoidBoundPointsWithDepth,
            imageSize: captureImageData.originalSize,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics
        )
        guard let widthAttributeValue = AccessibilityFeatureAttribute.width.valueFromDouble(Double(widthValue)) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return widthAttributeValue
    }
    
    func calculateRunningSlopeLegacy(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.depthMapProcessorKey)
        }
        guard let localizationProcessor = self.localizationProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.localizationProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let trapezoidBoundPoints = accessibilityFeature.contourDetails.trapezoidPoints,
              trapezoidBoundPoints.count == 4 else {
            throw AttributeEstimationPipelineError.invalidAttributeData
        }
        let trapezoidBoundDepthValues = try depthMapProcessor.getFeatureDepthsAtBounds(
            detectedFeature: accessibilityFeature
        )
        let trapezoidBoundPointsWithDepth: [PointWithDepth] = zip(trapezoidBoundPoints, trapezoidBoundDepthValues).map {
            PointWithDepth(
                point: CGPoint(x: CGFloat($0.0.x), y: CGFloat($0.0.y)),
                depth: $0.1
            )
        }
        let runningSlopeValue: Float = try localizationProcessor.calculateRunningSlope(
            trapezoidBoundsWithDepth: trapezoidBoundPointsWithDepth,
            imageSize: captureImageData.originalSize,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics
        )
        guard let runningSlopeAttributeValue = AccessibilityFeatureAttribute.runningSlope.valueFromDouble(
            Double(runningSlopeValue)
        ) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return runningSlopeAttributeValue
    }
    
    func calculateCrossSlopeLegacy(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.depthMapProcessorKey)
        }
        guard let localizationProcessor = self.localizationProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.localizationProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let trapezoidBoundPoints = accessibilityFeature.contourDetails.trapezoidPoints,
              trapezoidBoundPoints.count == 4 else {
            throw AttributeEstimationPipelineError.invalidAttributeData
        }
        let trapezoidBoundDepthValues = try depthMapProcessor.getFeatureDepthsAtBounds(
            detectedFeature: accessibilityFeature
        )
        let trapezoidBoundPointsWithDepth: [PointWithDepth] = zip(trapezoidBoundPoints, trapezoidBoundDepthValues).map {
            PointWithDepth(
                point: CGPoint(x: CGFloat($0.0.x), y: CGFloat($0.0.y)),
                depth: $0.1
            )
        }
        let crossSlopeValue: Float = try localizationProcessor.calculateCrossSlope(
            trapezoidBoundsWithDepth: trapezoidBoundPointsWithDepth,
            imageSize: captureImageData.originalSize,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics
        )
        guard let crossSlopeAttributeValue = AccessibilityFeatureAttribute.crossSlope.valueFromDouble(
            Double(crossSlopeValue)
        ) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return crossSlopeAttributeValue
    }
}
