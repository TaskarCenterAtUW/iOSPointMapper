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
    func calculateWidth(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.worldPointsProcessorKey)
        }
        guard let planeFitProcesor = self.planeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeProcessorKey)
        }
        guard let planeAttributeProcessor = self.planeAttributeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeAttributeProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let worldPoints: [WorldPoint] = try self.prerequisiteCache.worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        let alignedPlane: Plane = try self.prerequisiteCache.alignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, worldPoints: worldPoints
        )
        let projectedPoints = try worldPointsProcessor.projectPointsToPlane(
            worldPoints: worldPoints, plane: alignedPlane,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
        )
        let projectedPointBins = try planeAttributeProcessor.binProjectedPoints(projectedPoints: projectedPoints)
        let binWidths: [BinWidth] = planeAttributeProcessor.computeWidthByBin(projectedPointBins: projectedPointBins)
        let averageWidth = binWidths.reduce(0.0) { partialResult, binWidth in
            return partialResult + Double(binWidth.width)
        } / Double(binWidths.count)
        
        guard let widthAttributeValue = AccessibilityFeatureAttribute.width.valueFromDouble(Double(averageWidth)) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return widthAttributeValue
    }
    
    /**
        Function to calculate the running slope of the feature.
     
        Assumes that the plane being calculated has its first vector aligned with the direction of travel.
     */
    func calculateRunningSlope(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let planeFitProcesor = self.planeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let worldPoints: [WorldPoint] = try self.prerequisiteCache.worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        let alignedPlane: Plane = try self.prerequisiteCache.alignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, worldPoints: worldPoints
        )
        let runningVector = simd_normalize(alignedPlane.firstVector)
        let gravityVector = SIMD3<Float>(0, 1, 0)
        let rise = simd_dot(runningVector, gravityVector)
        let runningHorizontalVector = runningVector - (rise * gravityVector)
        let run = simd_length(runningHorizontalVector)
        let slopeRadians = atan2(rise, run)
        let slopeDegrees: Double = Double(abs(slopeRadians * (180.0 / .pi)))
//        print("Running vector: \(runningVector), \nRunning Horizontal Vector: \(runningHorizontalVector), \nRise: \(rise), Run: \(run), Slope Degrees: \(slopeDegrees)")
        
        guard let runningSlopeAttributeValue = AccessibilityFeatureAttribute.runningSlope.valueFromDouble(slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return runningSlopeAttributeValue
    }
    
    func calculateCrossSlope(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let planeFitProcesor = self.planeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let worldPoints: [WorldPoint] = try self.prerequisiteCache.worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        let alignedPlane: Plane = try self.prerequisiteCache.alignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, worldPoints: worldPoints
        )
        let crossVector = simd_normalize(alignedPlane.secondVector)
        let gravityVector = SIMD3<Float>(0, 1, 0)
        let rise = simd_dot(crossVector, gravityVector)
        let crossHorizontalVector = crossVector - (rise * gravityVector)
        let run = simd_length(crossHorizontalVector)
        let slopeRadians = atan2(rise, run)
        let slopeDegrees: Double = Double(abs(slopeRadians * (180.0 / .pi)))
//        print("Cross vector: \(crossVector), \nCross Horizontal Vector: \(crossHorizontalVector), \nRise: \(rise), Run: \(run), Slope Degrees: \(slopeDegrees)")
        
        guard let crossSlopeAttributeValue = AccessibilityFeatureAttribute.crossSlope.valueFromDouble(slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return crossSlopeAttributeValue
    }
}
