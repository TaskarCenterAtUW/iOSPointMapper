//
//  AttributeEstimationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreLocation

enum AttributeEstimationPipelineError: Error, LocalizedError {
    case configurationError
    case missingDepthImage
    
    var errorDescription: String? {
        switch self {
        case .configurationError:
            return NSLocalizedString("Error occurred during pipeline configuration.", comment: "")
        case .missingDepthImage:
            return NSLocalizedString("Depth image is missing from the capture data.", comment: "")
        }
    }
}

class AttributeEstimationPipeline: ObservableObject {
    var depthMapProcessor: DepthMapProcessor?
    var localizationProcessor: LocalizationProcessor?
    var captureImageData: (any CaptureImageDataProtocol)?
    var captureMeshData: (any CaptureMeshDataProtocol)?
    
    func configure(
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol)
    ) throws {
        let captureImageDataConcrete = CaptureImageData(captureImageData)
        guard let depthImage = captureImageDataConcrete.depthImage else {
            throw AttributeEstimationPipelineError.missingDepthImage
        }
        self.depthMapProcessor = try DepthMapProcessor(depthImage: depthImage)
        self.localizationProcessor = LocalizationProcessor()
        self.captureImageData = captureImageData
        self.captureMeshData = captureMeshData
    }
    
    func processLocationRequest(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: AccessibilityFeature
    ) throws -> CLLocationCoordinate2D {
        guard let depthMapProcessor = self.depthMapProcessor,
              let localizationProcessor = self.localizationProcessor,
              let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.configurationError
        }
        let captureImageDataConcrete = CaptureImageData(captureImageData)
        let featureDepthValue = try depthMapProcessor.getFeatureDepthAtCentroidInRadius(
            accessibilityFeature: accessibilityFeature, radius: 3
        )
        let featureCentroid = accessibilityFeature.detectedAccessibilityFeature.contourDetails.centroid
        let locationCoordinate = localizationProcessor.calculateLocation(
            point: featureCentroid, depth: featureDepthValue,
            imageSize: captureImageDataConcrete.originalSize,
            cameraTransform: captureImageDataConcrete.cameraTransform,
            cameraIntrinsics: captureImageDataConcrete.cameraIntrinsics,
            deviceLocation: deviceLocation
        )
        return locationCoordinate
    }
}
