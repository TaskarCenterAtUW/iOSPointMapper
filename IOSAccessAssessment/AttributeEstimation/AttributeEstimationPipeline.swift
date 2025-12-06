//
//  AttributeEstimationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreLocation

enum AttributeEstimationPipelineError: Error, LocalizedError {
    case configurationError(String)
    case missingCaptureData
    case missingDepthImage
    case invalidAttributeData
    case attributeAssignmentError
    
    var errorDescription: String? {
        switch self {
        case .configurationError(let missingDetail):
            return NSLocalizedString("Error occurred during pipeline configuration. Details: \(missingDetail)", comment: "")
        case .missingCaptureData:
            return NSLocalizedString("Captured data is missing for processing.", comment: "")
        case .missingDepthImage:
            return NSLocalizedString("Depth image is missing from the capture data.", comment: "")
        case .invalidAttributeData:
            return NSLocalizedString("Invalid attribute data encountered.", comment: "")
        case .attributeAssignmentError:
            return NSLocalizedString("Error occurred while assigning attribute value.", comment: "")
        }
    }
}

/**
    An attribute estimation pipeline that processes editable accessibility features to estimate their attributes.
 */
class AttributeEstimationPipeline: ObservableObject {
    enum Constants {
        enum Texts {
            static let depthMapProcessorKey = "Depth Map Processor"
            static let localizationProcessorKey = "Localization Processor"
        }
    }
    
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
        accessibilityFeature: EditableAccessibilityFeature
    ) throws {
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.depthMapProcessorKey)
        }
        guard let localizationProcessor = self.localizationProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.localizationProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let captureImageDataConcrete = CaptureImageData(captureImageData)
        let featureDepthValue = try depthMapProcessor.getFeatureDepthAtCentroidInRadius(
            detectedFeature: accessibilityFeature, radius: 3
        )
        let featureCentroid = accessibilityFeature.contourDetails.centroid
        let locationCoordinate = localizationProcessor.calculateLocation(
            point: featureCentroid, depth: featureDepthValue,
            imageSize: captureImageDataConcrete.originalSize,
            cameraTransform: captureImageDataConcrete.cameraTransform,
            cameraIntrinsics: captureImageDataConcrete.cameraIntrinsics,
            deviceLocation: deviceLocation
        )
        accessibilityFeature.setLocation(locationCoordinate)
    }
    
    func processAttributeRequest(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws {
        var attributeAssignmentFlagError = false
        for attribute in accessibilityFeature.accessibilityFeatureClass.attributes {
            do {
                switch attribute {
                case .width:
                    let widthAttributeValue = try self.calculateWidth(accessibilityFeature: accessibilityFeature)
                    try accessibilityFeature.setAttributeValue(widthAttributeValue, for: .width, isCalculated: true)
                case .runningSlope:
                    let runningSlopeAttributeValue = try self.calculateRunningSlope(accessibilityFeature: accessibilityFeature)
                    try accessibilityFeature.setAttributeValue(runningSlopeAttributeValue, for: .runningSlope, isCalculated: true)
                case .crossSlope:
                    let crossSlopeAttributeValue = try self.calculateCrossSlope(accessibilityFeature: accessibilityFeature)
                    try accessibilityFeature.setAttributeValue(crossSlopeAttributeValue, for: .crossSlope, isCalculated: true)
                default:
                    continue
                }
            } catch {
                attributeAssignmentFlagError = true
                print("Error processing attribute \(attribute) for feature \(accessibilityFeature.id): \(error.localizedDescription)")
            }
        }
        guard !attributeAssignmentFlagError else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
    }
}

/**
 Extension for attribute calculation with rudimentary methods.
 TODO: Improve upon these methods with more robust implementations.
 */
extension AttributeEstimationPipeline {
    private func calculateWidth(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.depthMapProcessorKey)
        }
        guard let localizationProcessor = self.localizationProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.localizationProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let trapezoidBoundPoints = accessibilityFeature.contourDetails.normalizedPoints
        guard trapezoidBoundPoints.count == 4 else {
            throw AttributeEstimationPipelineError.invalidAttributeData
        }
        let trapezoidBoundDepthValues = try depthMapProcessor.getFeatureDepthsAtBounds(
            detectedFeature: accessibilityFeature
        )
        let trapezoidBoundPointsWithDepth: [PointWithDepth] = zip(trapezoidBoundPoints, trapezoidBoundDepthValues).map {
            PointWithDepth(
                point: CGPoint(x: CGFloat($0.0.x), y: CGFloat($0.0.y)),
                depth: $0.1
            )
        }
        let widthValue = try localizationProcessor.calculateWidth(
            trapezoidBoundsWithDepth: trapezoidBoundPointsWithDepth,
            imageSize: captureImageData.originalSize,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics
        )
        guard let widthAttributeValue = AccessibilityFeatureAttribute.width.valueFromDouble(Double(widthValue)) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return widthAttributeValue
    }
    
    private func calculateRunningSlope(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.depthMapProcessorKey)
        }
        guard let localizationProcessor = self.localizationProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.localizationProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let trapezoidBoundPoints = accessibilityFeature.contourDetails.normalizedPoints
        guard trapezoidBoundPoints.count == 4 else {
            throw AttributeEstimationPipelineError.invalidAttributeData
        }
        let trapezoidBoundDepthValues = try depthMapProcessor.getFeatureDepthsAtBounds(
            detectedFeature: accessibilityFeature
        )
        let trapezoidBoundPointsWithDepth: [PointWithDepth] = zip(trapezoidBoundPoints, trapezoidBoundDepthValues).map {
            PointWithDepth(
                point: CGPoint(x: CGFloat($0.0.x), y: CGFloat($0.0.y)),
                depth: $0.1
            )
        }
        let runningSlopeValue: Float = try localizationProcessor.calculateRunningSlope(
            trapezoidBoundsWithDepth: trapezoidBoundPointsWithDepth,
            imageSize: captureImageData.originalSize,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics
        )
        guard let runningSlopeAttributeValue = AccessibilityFeatureAttribute.runningSlope.valueFromDouble(
            Double(runningSlopeValue)
        ) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return runningSlopeAttributeValue
    }
    
    private func calculateCrossSlope(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        guard let depthMapProcessor = self.depthMapProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.depthMapProcessorKey)
        }
        guard let localizationProcessor = self.localizationProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.localizationProcessorKey)
        }
        guard let captureImageData = self.captureImageData else {
            throw AttributeEstimationPipelineError.missingCaptureData
        }
        let trapezoidBoundPoints = accessibilityFeature.contourDetails.normalizedPoints
        guard trapezoidBoundPoints.count == 4 else {
            throw AttributeEstimationPipelineError.invalidAttributeData
        }
        let trapezoidBoundDepthValues = try depthMapProcessor.getFeatureDepthsAtBounds(
            detectedFeature: accessibilityFeature
        )
        let trapezoidBoundPointsWithDepth: [PointWithDepth] = zip(trapezoidBoundPoints, trapezoidBoundDepthValues).map {
            PointWithDepth(
                point: CGPoint(x: CGFloat($0.0.x), y: CGFloat($0.0.y)),
                depth: $0.1
            )
        }
        let crossSlopeValue: Float = try localizationProcessor.calculateCrossSlope(
            trapezoidBoundsWithDepth: trapezoidBoundPointsWithDepth,
            imageSize: captureImageData.originalSize,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics
        )
        guard let crossSlopeAttributeValue = AccessibilityFeatureAttribute.crossSlope.valueFromDouble(
            Double(crossSlopeValue)
        ) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return crossSlopeAttributeValue
    }
}
