//
//  OtherAttributeExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/25/26.
//
import SwiftUI
import CoreLocation

/**
 Extension for utilities related to world point extraction and plane calculation.
 */
extension AttributeEstimationPipeline {
    func getWorldPoints(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> [WorldPoint] {
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.depthMapProcessorKey)
        }
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.worldPointsProcessorKey)
        }
        let worldPoints = try worldPointsProcessor.getWorldPoints(
            segmentationLabelImage: captureImageData.captureImageDataResults.segmentationLabelImage,
            depthImage: depthMapProcessor.depthImage,
            targetValue: accessibilityFeature.accessibilityFeatureClass.labelValue,
            cameraTransform: captureImageData.cameraTransform, cameraIntrinsics: captureImageData.cameraIntrinsics
        )
        return worldPoints
    }
    
    /**
     Intermediary method to calculate the plane of the feature given the accessibility feature.
     */
    func calculateAlignedPlane(
        accessibilityFeature: EditableAccessibilityFeature,
        worldPoints: [WorldPoint]? = nil
    ) throws -> Plane {
        guard let planeFitProcesorLocal = self.planeFitProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeFitProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        var plane: Plane
        let worldPointsLocal: [WorldPoint] = try worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        plane = try planeFitProcesorLocal.fitPlanePCA(worldPoints: worldPointsLocal)
        let alignedPlane = try planeFitProcesorLocal.alignPlaneWithViewDirection(
            plane: plane,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
        )
        return alignedPlane
    }
    
    func calculateProjectedPlane(
        accessibilityFeature: EditableAccessibilityFeature,
        plane: Plane
    ) throws -> ProjectedPlane {
        guard let planeFitProcesor = self.planeFitProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeFitProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        
        let projectedPlane = try planeFitProcesor.projectPlane(
            plane: plane,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
        )
        return projectedPlane
    }
}

/**
 Extension for attribute calculation with rudimentary methods.
 TODO: Improve upon these methods with more robust implementations.
 */
extension AttributeEstimationPipeline {
    func calculateWidth(
        accessibilityFeature: EditableAccessibilityFeature,
        worldPoints: [WorldPoint]? = nil,
        alignedPlane: Plane? = nil
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let planeFitProcesor = self.planeFitProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeFitProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let worldPointsLocal: [WorldPoint] = try worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        let finalPlane: Plane
        if let alignedPlane = alignedPlane {
            finalPlane = alignedPlane
        } else {
            let plane = try calculateAlignedPlane(
                accessibilityFeature: accessibilityFeature, worldPoints: worldPointsLocal
            )
            finalPlane = try planeFitProcesor.alignPlaneWithViewDirection(
                plane: plane,
                cameraTransform: captureImageData.cameraTransform,
                cameraIntrinsics: captureImageData.cameraIntrinsics,
                imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
            )
        }
        
        guard let widthAttributeValue = AccessibilityFeatureAttribute.width.valueFromDouble(Double(0)) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return widthAttributeValue
    }
    
    /**
        Function to calculate the running slope of the feature.
     
        Assumes that the plane being calculated has its first vector aligned with the direction of travel.
     */
    func calculateRunningSlope(
        accessibilityFeature: EditableAccessibilityFeature,
        worldPoints: [WorldPoint]? = nil,
        alignedPlane: Plane? = nil
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let planeFitProcesor = self.planeFitProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeFitProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let finalPlane: Plane
        if let alignedPlane = alignedPlane {
            finalPlane = alignedPlane
        } else {
            let plane = try calculateAlignedPlane(accessibilityFeature: accessibilityFeature)
            finalPlane = try planeFitProcesor.alignPlaneWithViewDirection(
                plane: plane,
                cameraTransform: captureImageData.cameraTransform,
                cameraIntrinsics: captureImageData.cameraIntrinsics,
                imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
            )
        }
        let runningVector = simd_normalize(finalPlane.firstVector)
        let gravityVector = SIMD3<Float>(0, 1, 0)
        let rise = simd_dot(runningVector, gravityVector)
        let runningHorizontalVector = simd_normalize(runningVector - (rise * gravityVector))
        let run = simd_length(runningHorizontalVector)
        let slopeRadians = atan2(rise, run)
        let slopeDegrees: Double = Double(abs(slopeRadians * (180.0 / .pi)))
        
        guard let runningSlopeAttributeValue = AccessibilityFeatureAttribute.runningSlope.valueFromDouble(slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return runningSlopeAttributeValue
    }
    
    func calculateCrossSlope(
        accessibilityFeature: EditableAccessibilityFeature,
        worldPoints: [WorldPoint]? = nil,
        alignedPlane: Plane? = nil
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let planeFitProcesor = self.planeFitProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeFitProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let finalPlane: Plane
        if let alignedPlane = alignedPlane {
            finalPlane = alignedPlane
        } else {
            let plane = try calculateAlignedPlane(accessibilityFeature: accessibilityFeature)
            finalPlane = try planeFitProcesor.alignPlaneWithViewDirection(
                plane: plane,
                cameraTransform: captureImageData.cameraTransform,
                cameraIntrinsics: captureImageData.cameraIntrinsics,
                imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
            )
        }
        let crossVector = simd_normalize(finalPlane.secondVector)
        let gravityVector = SIMD3<Float>(0, 1, 0)
        let rise = simd_dot(crossVector, gravityVector)
        let crossHorizontalVector = simd_normalize(crossVector - (rise * gravityVector))
        let run = simd_length(crossHorizontalVector)
        let slopeRadians = atan2(rise, run)
        let slopeDegrees: Double = Double(abs(slopeRadians * (180.0 / .pi)))
        
        guard let crossSlopeAttributeValue = AccessibilityFeatureAttribute.crossSlope.valueFromDouble(slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return crossSlopeAttributeValue
    }
}
