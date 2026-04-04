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
    ) throws {
        let damageDetectionResults = try getDamageDetectionResults(accessibilityFeature: accessibilityFeature)
        
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
//        let originalSize = cameraImage.extent.size
        let croppedSize = Constants.DamageDetectionConstants.inputSize
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: captureImageData.interfaceOrientation
        )
//        let inverseOrientation = imageOrientation.inverted()
        
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
        
//        let finalBox = CGRect(
//            x: translatedBox.origin.x * originalSize.width,
//            y: (1 - (translatedBox.origin.y + translatedBox.size.height)) * originalSize.height,
//            width: translatedBox.size.width * originalSize.width,
//            height: translatedBox.size.height * originalSize.height
//        )
//        return finalBox
    }
}
