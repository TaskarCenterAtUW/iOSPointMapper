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
        let damageDetectionResults = try getDamageDetectionResults()
        
    }
    
    private func getDamageDetectionResults() throws -> [DamageDetectionResult] {
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        guard let damageDetectionPipeline = self.damageDetectionPipeline else {
            throw AttributeEstimationPipelineError.missingPreprocessors
        }
        /// Run damage detection
        let cameraImage = captureImageData.cameraImage
        let originalSize = cameraImage.extent.size
        let croppedSize = Constants.DamageDetectionConstants.inputSize
        let imageOrientation: CGImagePropertyOrientation = CameraOrientation.getCGImageOrientationForInterface(
            currentInterfaceOrientation: captureImageData.interfaceOrientation
        )
        let inverseOrientation = imageOrientation.inverted()
        
        let orientedImage = cameraImage.oriented(imageOrientation)
        var inputImage = CenterCropTransformUtils.centerCropAspectFit(orientedImage, to: croppedSize)
        
        let damageDetectionResults: [DamageDetectionResult] = try damageDetectionPipeline.processRequest(with: inputImage)
        
        /// TODO: Need to re-align the bounding boxes from the model back to the original image orientation and size. This is needed to map the bounding boxes to the correct location on the original image for accurate annotation and visualization.
        
        return damageDetectionResults
    }
    
//    private func alignBoundingBox(_ boundingBox: CGRect, orientation: CGImagePropertyOrientation, imageSize: CGSize, originalSize: CGSize) -> CGRect {
//        var orientationTransform = orientation.getNormalizedToUpTransform().inverted()
//        
//        let alignedBox = boundingBox.applying(orientationTransform)
//        
//        // Revert the center-cropping effect to map back to original image size
//        
//        let translatedBox = translateBoundingBoxToRevertCenterCrop(alignedBox, imageSize: imageSize, originalSize: originalSize)
//        
//        let finalBox = CGRect(
//            x: translatedBox.origin.x * originalSize.width,
//            y: (1 - (translatedBox.origin.y + translatedBox.size.height)) * originalSize.height,
//            width: translatedBox.size.width * originalSize.width,
//            height: translatedBox.size.height * originalSize.height
//        )
//        
//        return finalBox
//    }
}
