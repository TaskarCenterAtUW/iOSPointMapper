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
        guard let planeProcessorLocal = self.planeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeProcessorKey)
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
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeProcessorKey)
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
    func getMeshPolygons(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> MeshContents {
        guard let captureMeshData = self.captureMeshData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let capturedMeshSnapshot = captureMeshData.captureMeshDataResults.segmentedMesh
        let meshContents: MeshContents = try CapturedMeshSnapshotHelper.readFeatureSnapshot(
            capturedMeshSnapshot: capturedMeshSnapshot,
            accessibilityFeatureClass: accessibilityFeature.accessibilityFeatureClass
        )
        return meshContents
    }
}
