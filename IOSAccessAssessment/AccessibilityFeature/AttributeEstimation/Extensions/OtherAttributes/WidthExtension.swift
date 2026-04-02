//
//  WidthExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/2/26.
//

import SwiftUI
import CoreLocation

extension AttributeEstimationPipeline {
    func calculateWidth(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        let isMeshEnabled: Bool = self.captureMeshData != nil
        if isMeshEnabled {
            return try self.calculateWidthFromMesh(accessibilityFeature: accessibilityFeature)
        }
        return try self.calculateWidthFromImage(accessibilityFeature: accessibilityFeature)
    }
    
    func calculateWidthFromImage(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(AttributeEstimationPipelineConstants.Texts.worldPointsProcessorKey)
        }
        guard let planeAttributeProcessor = self.planeAttributeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(AttributeEstimationPipelineConstants.Texts.planeAttributeProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let worldPoints: [WorldPoint] = try self.prerequisiteCache.worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        let alignedPlane: Plane = try self.prerequisiteCache.pointAlignedPlane ?? self.calculateAlignedPlane(
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
    
    func calculateWidthFromMesh(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(AttributeEstimationPipelineConstants.Texts.worldPointsProcessorKey)
        }
        guard let planeAttributeProcessor = self.planeAttributeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(AttributeEstimationPipelineConstants.Texts.planeAttributeProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        /// First, get the reference bins from mesh triangle centroids
        let meshPolygons: [MeshPolygon] = try self.prerequisiteCache.meshPolygons ?? self.getMeshContents(
            accessibilityFeature: accessibilityFeature
        ).polygons
        let alignedPlane: Plane = try self.prerequisiteCache.meshAlignedPlane ?? self.calculateAlignedPlane(
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
        let meshProjectedPointBins = try planeAttributeProcessor.binMeshTriangles(
            meshTriangles: meshTriangles, initialProjectedPointBins: projectedPointBins,
            plane: alignedPlane
        )
        let binWidths: [BinWidth] = planeAttributeProcessor.computeWidthByBin(
            projectedPointBins: meshProjectedPointBins, minCount: 10
        )
        let averageWidth = binWidths.reduce(0.0) { partialResult, binWidth in
            return partialResult + Double(binWidth.width)
        } / Double(binWidths.count)
        
        guard let widthAttributeValue = AccessibilityFeatureAttribute.width.valueFromDouble(Double(averageWidth)) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return widthAttributeValue
    }
}
