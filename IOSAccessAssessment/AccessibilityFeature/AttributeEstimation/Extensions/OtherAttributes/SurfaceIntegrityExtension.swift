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
        return try calculateSurfaceIntegrityFromImage(accessibilityFeature: accessibilityFeature)
    }
    
    func calculateSurfaceIntegrityFromImage(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let surfaceNormalsProcessor = self.surfaceNormalsProcessor else {
            throw AttributeEstimationPipelineError.missingPreprocessors
        }
        let damageDetectionResults = try getDamageDetectionResults(accessibilityFeature: accessibilityFeature)
        let worldPointsGrid = try self.prerequisiteCache.worldPointsGrid ?? self.getWorldPointsGrid(accessibilityFeature: accessibilityFeature)
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
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
        
        var surfaceIntegrity: Bool = false
        if damageDetectionResults.count > 0 {
            surfaceIntegrity = true
        }
        guard let surfaceIntegrityAttributeValue = AccessibilityFeatureAttribute.surfaceIntegrity.valueFromBool(
            surfaceIntegrity
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
}
