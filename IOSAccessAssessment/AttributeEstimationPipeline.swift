//
//  AttributeEstimationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreLocation

enum AttributeEstimationPipelineError: Error, LocalizedError {
    case missingDepthImage
    
    var errorDescription: String? {
        switch self {
        case .missingDepthImage:
            return NSLocalizedString("Depth image is missing from the capture data.", comment: "")
        }
    }
}

class AttributeEstimationPipeline: ObservableObject {
    let depthMapProcessor: DepthMapProcessor
    let localizationProcessor: LocalizationProcessor
    
    init(
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol)
    ) throws {
        let captureImageDataConcrete = CaptureImageData(captureImageData)
        guard let depthImage = captureImageDataConcrete.depthImage else {
            throw AttributeEstimationPipelineError.missingDepthImage
        }
        self.depthMapProcessor = try DepthMapProcessor(depthImage: depthImage)
        self.localizationProcessor = LocalizationProcessor()
    }
    
    func processLocationRequest(
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol),
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: AccessibilityFeature
    ) throws -> CLLocationCoordinate2D {
        let captureImageDataConcrete = CaptureImageData(captureImageData)
        let featureDepthValue = try self.depthMapProcessor.getFeatureDepthAtCentroidInRadius(
            accessibilityFeature: accessibilityFeature, radius: 3
        )
        let featureCentroid = accessibilityFeature.detectedAccessibilityFeature.contourDetails.centroid
        let imageSize = captureImageDataConcrete.originalSize
        let locationCoordinate = self.localizationProcessor.calculateLocation(
            point: featureCentroid, depth: featureDepthValue,
            imageSize: captureImageDataConcrete.originalSize,
            cameraTransform: captureImageDataConcrete.cameraTransform,
            cameraIntrinsics: captureImageDataConcrete.cameraIntrinsics,
            deviceLocation: deviceLocation
        )
        return locationCoordinate
    }
}
