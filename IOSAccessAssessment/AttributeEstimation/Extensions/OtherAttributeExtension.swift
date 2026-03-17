//
//  OtherAttributeExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/25/26.
//
import SwiftUI
import CoreLocation

extension AttributeEstimationPipeline {
    func calculateWidth(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        let isMeshEnabled: Bool = captureMeshData != nil
        if isMeshEnabled {
            return try self.calculateWidthFromMesh(accessibilityFeature: accessibilityFeature)
        }
        return try self.calculateWidthFromImage(accessibilityFeature: accessibilityFeature)
    }
    
    func calculateRunningSlope(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        let isMeshEnabled: Bool = captureMeshData != nil
        if isMeshEnabled {
            return try self.calculateRunningSlopeFromMesh(accessibilityFeature: accessibilityFeature)
        }
        return try self.calculateRunningSlopeFromImage(accessibilityFeature: accessibilityFeature)
    }
    
    func calculateCrossSlope(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        let isMeshEnabled: Bool = captureMeshData != nil
        if isMeshEnabled {
            return try self.calculateCrossSlopeFromMesh(accessibilityFeature: accessibilityFeature)
        }
        return try self.calculateCrossSlopeFromImage(accessibilityFeature: accessibilityFeature)
    }
}

/**
 Extension for attribute calculation with plane-fitting approach.
 */
extension AttributeEstimationPipeline {
    func calculateWidthFromImage(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.worldPointsProcessorKey)
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
    func calculateRunningSlopeFromImage(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
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
        
        guard let runningSlopeAttributeValue = AccessibilityFeatureAttribute.runningSlope.valueFromDouble(slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return runningSlopeAttributeValue
    }
    
    func calculateCrossSlopeFromImage(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
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
        
        guard let crossSlopeAttributeValue = AccessibilityFeatureAttribute.crossSlope.valueFromDouble(slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return crossSlopeAttributeValue
    }
}

extension AttributeEstimationPipeline {
    func calculateWidthFromMesh(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.worldPointsProcessorKey)
        }
        guard let planeAttributeProcessor = self.planeAttributeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeAttributeProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        /// First, get the reference bins from mesh triangle centroids
        let meshPolygons: [MeshPolygon] = try self.prerequisiteCache.meshPolygons ?? self.getMeshContents(
            accessibilityFeature: accessibilityFeature
        ).polygons
        let alignedPlane: Plane = try self.prerequisiteCache.alignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, meshPolygons: meshPolygons
        )
        let worldPointsFromMesh: [WorldPoint] = meshPolygons.map { triangle in
            return WorldPoint(p: triangle.centroid)
        }
        let projectedPoints = try worldPointsProcessor.projectPointsToPlane(
            worldPoints: worldPointsFromMesh, plane: alignedPlane,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
        )
        let projectedPointBins = try planeAttributeProcessor.binProjectedPoints(projectedPoints: projectedPoints)
        /// Then, get the actual bins from the mesh triangles themselves
        let meshTriangles: [MeshTriangle] = try self.prerequisiteCache.meshTriangles ?? self.getMeshContents(
            accessibilityFeature: accessibilityFeature
        ).triangles
        let meshTriangleBins = try planeAttributeProcessor.binMeshTriangles(
            meshTriangles: meshTriangles, initialProjectedPointBins: projectedPointBins,
            plane: alignedPlane
        )
        let binWidths: [BinWidth] = planeAttributeProcessor.computeWidthByBin(projectedPointBins: meshTriangleBins, minCount: 10)
        let averageWidth = binWidths.reduce(0.0) { partialResult, binWidth in
            return partialResult + Double(binWidth.width)
        } / Double(binWidths.count)
        
        guard let widthAttributeValue = AccessibilityFeatureAttribute.width.valueFromDouble(Double(averageWidth)) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return widthAttributeValue
    }
    
    func calculateRunningSlopeFromMesh(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        let meshPolygons: [MeshPolygon] = try self.prerequisiteCache.meshPolygons ?? self.getMeshContents(
            accessibilityFeature: accessibilityFeature
        ).polygons
        let alignedPlane: Plane = try self.prerequisiteCache.alignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, meshPolygons: meshPolygons
        )
        let runningVector = simd_normalize(alignedPlane.firstVector)
        let gravityVector = SIMD3<Float>(0, 1, 0)
        let rise = simd_dot(runningVector, gravityVector)
        let runningHorizontalVector = runningVector - (rise * gravityVector)
        let run = simd_length(runningHorizontalVector)
        let slopeRadians = atan2(rise, run)
        let slopeDegrees: Double = Double(abs(slopeRadians * (180.0 / .pi)))
        
        guard let runningSlopeAttributeValue = AccessibilityFeatureAttribute.runningSlope.valueFromDouble(slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return runningSlopeAttributeValue
    }
    
    func calculateCrossSlopeFromMesh(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        let meshPolygons: [MeshPolygon] = try self.prerequisiteCache.meshPolygons ?? self.getMeshContents(
            accessibilityFeature: accessibilityFeature
        ).polygons
        let alignedPlane: Plane = try self.prerequisiteCache.alignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, meshPolygons: meshPolygons
        )
        let crossVector = simd_normalize(alignedPlane.secondVector)
        let gravityVector = SIMD3<Float>(0, 1, 0)
        let rise = simd_dot(crossVector, gravityVector)
        let crossHorizontalVector = crossVector - (rise * gravityVector)
        let run = simd_length(crossHorizontalVector)
        let slopeRadians = atan2(rise, run)
        let slopeDegrees: Double = Double(abs(slopeRadians * (180.0 / .pi)))
        
        guard let crossSlopeAttributeValue = AccessibilityFeatureAttribute.crossSlope.valueFromDouble(slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return crossSlopeAttributeValue
    }
}
