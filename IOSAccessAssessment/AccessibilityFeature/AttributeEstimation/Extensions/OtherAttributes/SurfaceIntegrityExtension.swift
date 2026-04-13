//
//  SurfaceIntegrityExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/2/26.
//

import SwiftUI
import CoreLocation

extension AttributeEstimationPipeline {
    func calculateSurfaceIntegrity(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        let isMeshEnabled: Bool = self.captureMeshData != nil
        if isMeshEnabled {
            return try calculateSurfaceIntegrityFromMesh(accessibilityFeature: accessibilityFeature)
        }
        return try calculateSurfaceIntegrityFromImage(accessibilityFeature: accessibilityFeature)
    }
    
    func calculateSurfaceIntegrityFromImage(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let surfaceNormalsProcessor = self.surfaceNormalsProcessor else {
            throw AttributeEstimationPipelineError.missingPreprocessors
        }
        guard let surfaceIntegrityProcessor = self.surfaceIntegrityProcessor else {
            throw AttributeEstimationPipelineError.missingPreprocessors
        }
        let damageDetectionResults = try getDamageDetectionResults(accessibilityFeature: accessibilityFeature)
        let worldPointsGrid = try self.prerequisiteCache.worldPointsGrid ?? self.getWorldPointsGrid(accessibilityFeature: accessibilityFeature)
        let worldPoints: [WorldPoint] = try self.prerequisiteCache.worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        let alignedPlane: Plane = try self.prerequisiteCache.pointAlignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, worldPoints: worldPoints
        )
        let projectedPlane: ProjectedPlane = try self.prerequisiteCache.pointProjectedPlane ?? self.calculateProjectedPlane(
            accessibilityFeature: accessibilityFeature, plane: alignedPlane
        )
        let surfaceNormalsGrid: SurfaceNormalsForPointsGrid = try surfaceNormalsProcessor.getSurfaceNormalsFromWorldPoints(
            worldPointsGrid: worldPointsGrid, plane: alignedPlane, projectedPlane: projectedPlane
        )
        let surfaceIntegrityResults = try surfaceIntegrityProcessor.getIntegrityResultsFromImage(
            worldPointsGrid: worldPointsGrid, plane: alignedPlane, surfaceNormalsForPointsGrid: surfaceNormalsGrid,
            damageDetectionResults: damageDetectionResults, captureData: captureImageData
        )
        
        let surfaceIntegrity = processSurfaceIntegrityResults(integrityResults: surfaceIntegrityResults)
        guard let surfaceIntegrityAttributeValue = AccessibilityFeatureAttribute.surfaceIntegrity.value(
            from: surfaceIntegrity
        ) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return surfaceIntegrityAttributeValue
    }
    
    func calculateSurfaceIntegrityFromMesh(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let captureMeshData = self.captureMeshData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let surfaceIntegrityProcessor = self.surfaceIntegrityProcessor else {
            throw AttributeEstimationPipelineError.missingPreprocessors
        }
        let damageDetectionResults = try getDamageDetectionResults(accessibilityFeature: accessibilityFeature)
        let meshContents: MeshContents = try self.prerequisiteCache.meshContents ?? self.getMeshContents(
            accessibilityFeature: accessibilityFeature
        )
        let meshPolygons: [MeshPolygon] = self.prerequisiteCache.meshPolygons ?? meshContents.polygons
        let meshTriangles: [MeshTriangle] = self.prerequisiteCache.meshTriangles ?? meshContents.triangles
        let alignedPlane: Plane = try self.prerequisiteCache.meshAlignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, meshPolygons: meshPolygons
        )
//        let projectedPlane: ProjectedPlane = try self.prerequisiteCache.meshProjectedPlane ?? self.calculateProjectedPlane(
//            accessibilityFeature: accessibilityFeature, plane: alignedPlane
//        )
        let surfaceIntegrityResults = try surfaceIntegrityProcessor.getIntegrityResultsFromMesh(
            meshTriangles: meshTriangles, plane: alignedPlane,
            damageDetectionResults: damageDetectionResults, captureData: captureMeshData
        )
        
        let surfaceIntegrity = processSurfaceIntegrityResults(integrityResults: surfaceIntegrityResults)
        guard let surfaceIntegrityAttributeValue = AccessibilityFeatureAttribute.surfaceIntegrity.value(
            from: surfaceIntegrity
        ) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return surfaceIntegrityAttributeValue
    }
    
    func getDamageDetectionResults(accessibilityFeature: EditableAccessibilityFeature) throws -> [DamageDetectionResult] {
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let damageDetectionPipeline = self.damageDetectionPipeline else {
            throw AttributeEstimationPipelineError.missingPreprocessors
        }
        /// Run damage detection
        let cameraImage = captureImageData.cameraImage
        let croppedSize = Constants.DamageDetectionConstants.inputSize
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: captureImageData.interfaceOrientation
        )
        
        let orientedImage = cameraImage.oriented(imageOrientation)
        let inputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        let damageDetectionResults: [DamageDetectionResult] = try damageDetectionPipeline.processRequest(with: inputImage)
        let alignedDamageDetectionResults = damageDetectionResults.map { result -> DamageDetectionResult in
            let alignedBox = self.alignBoundingBox(result.boundingBox, orientation: imageOrientation, imageSize: croppedSize, originalSize: cameraImage.extent.size)
            return DamageDetectionResult(
                boundingBox: alignedBox,
                confidence: result.confidence,
                label: result.label
            )
        }
        
        return alignedDamageDetectionResults
    }
    
    private func alignBoundingBox(_ boundingBox: CGRect, orientation: CGImagePropertyOrientation, imageSize: CGSize, originalSize: CGSize) -> CGRect {
        let orientationTransform = orientation.getNormalizedToUpTransform().inverted()
        let revertTransform = CenterCropTransformUtils.revertCenterCropAspectFitNormalizedTransform(
            imageSize: imageSize, from: originalSize)
        let alignTransform = orientationTransform.concatenating(revertTransform)
        
        let alignedBox = boundingBox.applying(alignTransform)
        return alignedBox
    }
    
    private func processSurfaceIntegrityResults(integrityResults: IntegrityResults) -> SurfaceIntegrityStatus {
        /// We look for the most severe status across all integrity results to determine the overall surface integrity status.
        let worstStatus: SurfaceIntegrityStatus = max(
            integrityResults.boundingBoxAreaStatusDetails.status,
            integrityResults.boundingBoxSurfaceNormalStatusDetails.status,
            integrityResults.surfaceNormalStatusDetails.status
        )
        return worstStatus
    }
}
