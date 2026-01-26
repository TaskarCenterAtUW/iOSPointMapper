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

struct LocationRequestResult: Sendable {
    let coordinates: [[CLLocationCoordinate2D]]
    let locationDelta: SIMD2<Float>
    let lidarDepth: Float
}

/**
    An attribute estimation pipeline that processes editable accessibility features to estimate their attributes.
 */
class AttributeEstimationPipeline: ObservableObject {
    enum Constants {
        enum Texts {
            static let depthMapProcessorKey = "Depth Map Processor"
            static let localizationProcessorKey = "Localization Processor"
            static let planeFitProcessorKey = "Plane Fit Processor"
        }
    }
    
    var depthMapProcessor: DepthMapProcessor?
    var localizationProcessor: LocalizationProcessor?
    var planeFitProcessor: PlaneFitProcessor?
    var captureImageData: (any CaptureImageDataProtocol)?
    var captureMeshData: (any CaptureMeshDataProtocol)?
    
    /// TODO: MESH PROCESSING: Add mesh data processing components when needed.
    func configure(
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol)?
    ) throws {
        let captureImageDataConcrete = CaptureImageData(captureImageData)
        guard let depthImage = captureImageDataConcrete.depthImage else {
            throw AttributeEstimationPipelineError.missingDepthImage
        }
        self.depthMapProcessor = try DepthMapProcessor(depthImage: depthImage)
        self.localizationProcessor = LocalizationProcessor()
        self.planeFitProcessor = try PlaneFitProcessor()
        self.captureImageData = captureImageData
        self.captureMeshData = captureMeshData
    }
    
    func processLocationRequest(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws {
        var locationRequestResult: LocationRequestResult
        let oswElementClass = accessibilityFeature.accessibilityFeatureClass.oswPolicy.oswElementClass
        switch(oswElementClass) {
        case .Sidewalk:
            locationRequestResult = try self.calculateLocationForLineString(
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        case .Building:
            locationRequestResult = try self.calculateLocationForPolygon(
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        default:
            locationRequestResult = try self.calculateLocationForPoint(
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        }
        accessibilityFeature.setLocationDetails(coordinates: locationRequestResult.coordinates)
        /// Set Lidar Depth as experimental attribute
        if let lidarDepthAttributeValue = AccessibilityFeatureAttribute.lidarDepth.valueFromDouble(
            Double(locationRequestResult.lidarDepth)
        ) {
            do {
                try accessibilityFeature.setExperimentalAttributeValue(lidarDepthAttributeValue, for: .lidarDepth)
            } catch {
                print("Error setting lidar depth attribute for feature \(accessibilityFeature.id): \(error.localizedDescription)")
            }
        }
        if let latitudeDeltaAttributeValue = AccessibilityFeatureAttribute.latitudeDelta.valueFromDouble(
            Double(locationRequestResult.locationDelta.x)
        ) {
            do {
                try accessibilityFeature.setExperimentalAttributeValue(latitudeDeltaAttributeValue, for: .latitudeDelta)
            } catch {
                print("Error setting latitude delta attribute for feature " +
                      "\(accessibilityFeature.id): \(error.localizedDescription)")
            }
        }
        if let longitudeDeltaAttributeValue = AccessibilityFeatureAttribute.longitudeDelta.valueFromDouble(
            Double(locationRequestResult.locationDelta.y)
        ) {
            do {
                try accessibilityFeature.setExperimentalAttributeValue(longitudeDeltaAttributeValue, for: .longitudeDelta)
            } catch {
                print("Error setting longitude delta attribute for feature " +
                      "\(accessibilityFeature.id): \(error.localizedDescription)")
            }
        }
           
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
                case .widthLegacy:
                    let widthAttributeValue = try self.calculateWidthLegacy(accessibilityFeature: accessibilityFeature)
                    try accessibilityFeature.setAttributeValue(widthAttributeValue, for: .widthLegacy, isCalculated: true)
                case .runningSlopeLegacy:
                    let runningSlopeAttributeValue = try self.calculateRunningSlopeLegacy(accessibilityFeature: accessibilityFeature)
                    try accessibilityFeature.setAttributeValue(runningSlopeAttributeValue, for: .runningSlopeLegacy, isCalculated: true)
                case .crossSlopeLegacy:
                    let crossSlopeAttributeValue = try self.calculateCrossSlopeLegacy(accessibilityFeature: accessibilityFeature)
                    try accessibilityFeature.setAttributeValue(crossSlopeAttributeValue, for: .crossSlopeLegacy, isCalculated: true)
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
