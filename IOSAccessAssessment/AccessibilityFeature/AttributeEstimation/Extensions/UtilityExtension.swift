//
//  UtilityExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/15/26.
//
import SwiftUI
import CoreLocation

/**
 Extension for utilities related to world point extraction and plane calculation.
 */
extension AttributeEstimationPipeline {
    /**
     Get world points corresponding to the feature based on the segmentation label image and depth map, using the world points processor.
     */
    func getWorldPoints(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> [WorldPoint] {
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(AttributeEstimationPipelineConstants.Texts.depthMapProcessorKey)
        }
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(AttributeEstimationPipelineConstants.Texts.worldPointsProcessorKey)
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
     Restructure world points into a 2D grid based on their projected pixel coordinates, for more efficient spatial queries.
     */
    func getWorldPointsGrid(accessibilityFeature: EditableAccessibilityFeature) throws -> WorldPointsGrid {
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(
                AttributeEstimationPipelineConstants.Texts.worldPointsProcessorKey
            )
        }
        let worldPoints: [WorldPoint] = try self.prerequisiteCache.worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        let worldPointsGrid: WorldPointsGrid = try worldPointsProcessor.getWorldPointsGrid(
            worldPoints: worldPoints,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.originalSize
        )
        let _ = try worldPointsProcessor.getWorldPointsGridCPU(
            worldPoints: worldPoints,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.originalSize
        )
        return worldPointsGrid
    }
    
    /**
     Intermediary method to calculate the plane of the feature given the accessibility feature.
     */
    func calculateAlignedPlane(
        accessibilityFeature: EditableAccessibilityFeature,
        worldPoints: [WorldPoint]? = nil
    ) throws -> Plane {
        guard let planeProcessorLocal = self.planeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(AttributeEstimationPipelineConstants.Texts.planeProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        var plane: Plane
        let worldPointsLocal: [WorldPoint] = try worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        plane = try planeProcessorLocal.fitPlanePCA(worldPoints: worldPointsLocal)
        let alignedPlane = try planeProcessorLocal.alignPlaneWithViewDirection(
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
        guard let planeProcessor = self.planeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(AttributeEstimationPipelineConstants.Texts.planeProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        
        let projectedPlane = try planeProcessor.projectPlane(
            plane: plane,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
        )
        return projectedPlane
    }
}

/**
 Extension for utilities related to mesh polygon extraction and plane calculation.
 */
extension AttributeEstimationPipeline {
    func getMeshContents(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> MeshContents {
        guard let captureMeshData = self.captureMeshData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let capturedMeshSnapshot = captureMeshData.captureMeshDataResults.segmentedMesh
        /// WARNING: We are using the mesh corresponding to the entire class, not the specific feature.
        /// We will have to refine this in the future to get the mesh corresponding to the specific feature, especially when there are multiple instances of the same class.
        let meshContents: MeshContents = try CapturedMeshSnapshotHelper.readFeatureSnapshot(
            capturedMeshSnapshot: capturedMeshSnapshot,
            accessibilityFeatureClass: accessibilityFeature.accessibilityFeatureClass
        )
        return meshContents
    }
    
    func calculateAlignedPlane(
        accessibilityFeature: EditableAccessibilityFeature,
        meshPolygons: [MeshPolygon]? = nil
    ) throws -> Plane {
        guard let planeProcessorLocal = self.planeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(AttributeEstimationPipelineConstants.Texts.planeProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        var plane: Plane
        /// Using the vertices of the mesh polygons as points to fit the plane.
        let meshPolygonsLocal: [MeshPolygon] = try meshPolygons ?? self.getMeshContents(
            accessibilityFeature: accessibilityFeature
        ).polygons
        let worldPointsFromMesh: [WorldPoint] = meshPolygonsLocal.map { triangle in
            return WorldPoint(p: triangle.centroid)
        }
        let areasFromMesh: [Float] = meshPolygonsLocal.map { triangle in
            return triangle.area
        }
        plane = try planeProcessorLocal.fitPlanePCA(points: worldPointsFromMesh, weights: areasFromMesh)
        let alignedPlane = try planeProcessorLocal.alignPlaneWithViewDirection(
            plane: plane,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
        )
        return alignedPlane
    }
}
