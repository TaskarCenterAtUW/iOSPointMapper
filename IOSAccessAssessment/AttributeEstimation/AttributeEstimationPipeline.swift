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
        }
    }
    
    var depthMapProcessor: DepthMapProcessor?
    var localizationProcessor: LocalizationProcessor?
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
 Extension for additional location processing methods.
 */
extension AttributeEstimationPipeline {
    private func calculateLocationForPoint(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> LocationRequestResult {
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
        return try getLocationFromCentroid(
            depthMapProcessor: depthMapProcessor,
            localizationProcessor: localizationProcessor,
            captureImageData: captureImageDataConcrete,
            deviceLocation: deviceLocation,
            accessibilityFeature: accessibilityFeature
        )
    }
    
    private func calculateLocationForLineString(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> LocationRequestResult {
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
        do {
            return try getLocationFromTrapezoid(
                depthMapProcessor: depthMapProcessor,
                localizationProcessor: localizationProcessor,
                captureImageData: captureImageDataConcrete,
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        } catch {
            return try getLocationFromCentroid(
                depthMapProcessor: depthMapProcessor,
                localizationProcessor: localizationProcessor,
                captureImageData: captureImageDataConcrete,
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        }
    }
    
    private func calculateLocationForPolygon(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> LocationRequestResult {
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
        do {
            return try getLocationFromPolygon(
                depthMapProcessor: depthMapProcessor,
                localizationProcessor: localizationProcessor,
                captureImageData: captureImageDataConcrete,
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        } catch {
            return try getLocationFromCentroid(
                depthMapProcessor: depthMapProcessor,
                localizationProcessor: localizationProcessor,
                captureImageData: captureImageDataConcrete,
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        }
    }
    
    private func getLocationFromCentroid(
        depthMapProcessor: DepthMapProcessor,
        localizationProcessor: LocalizationProcessor,
        captureImageData: CaptureImageData,
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> LocationRequestResult {
        let featureDepthValue = try depthMapProcessor.getFeatureDepthAtCentroidInRadius(
            detectedFeature: accessibilityFeature, radius: 3
        )
        let featureCentroid = accessibilityFeature.contourDetails.centroid
        let locationDelta = localizationProcessor.calculateDelta(
            point: featureCentroid, depth: featureDepthValue,
            imageSize: captureImageData.originalSize,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics
        )
        let locationCoordinate = localizationProcessor.calculateLocation(
            point: featureCentroid, depth: featureDepthValue,
            imageSize: captureImageData.originalSize,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            deviceLocation: deviceLocation
        )
        let coordinates: [[CLLocationCoordinate2D]] = [[locationCoordinate]]
        return LocationRequestResult(
            coordinates: coordinates, locationDelta: locationDelta, lidarDepth: featureDepthValue
        )
    }
    
    private func getLocationFromTrapezoid(
        depthMapProcessor: DepthMapProcessor,
        localizationProcessor: LocalizationProcessor,
        captureImageData: CaptureImageData,
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> LocationRequestResult {
        let trapezoidBoundPoints = accessibilityFeature.contourDetails.normalizedPoints
        guard trapezoidBoundPoints.count == 4 else {
            throw AttributeEstimationPipelineError.invalidAttributeData
        }
        let bottomCenter = simd_float2(
            x: (trapezoidBoundPoints[0].x + trapezoidBoundPoints[3].x) / 2,
            y: (trapezoidBoundPoints[0].y + trapezoidBoundPoints[3].y) / 2
        )
        let topCenter = simd_float2(
            x: (trapezoidBoundPoints[1].x + trapezoidBoundPoints[2].x) / 2,
            y: (trapezoidBoundPoints[1].y + trapezoidBoundPoints[2].y) / 2
        )
        let points = [topCenter, bottomCenter] /// Flipped because of image coordinate system
        let pointDepthValues = try depthMapProcessor.getFeatureDepthsAtNormalizedPoints(points)
        let pointsWithDepth: [PointWithDepth] = zip(points, pointDepthValues).map {
            return PointWithDepth(point: CGPoint(x: CGFloat($0.0.x), y: CGFloat($0.0.y)), depth: $0.1)
        }
        /// For debugging
        let locationDeltas: [SIMD2<Float>] = pointsWithDepth.map { pointWithDepth in
            return localizationProcessor.calculateDelta(
                point: pointWithDepth.point, depth: pointWithDepth.depth,
                imageSize: captureImageData.originalSize,
                cameraTransform: captureImageData.cameraTransform,
                cameraIntrinsics: captureImageData.cameraIntrinsics
            )
        }
        let locationCoordinates: [CLLocationCoordinate2D] = pointsWithDepth.map { pointWithDepth in
            return localizationProcessor.calculateLocation(
                point: pointWithDepth.point, depth: pointWithDepth.depth,
                imageSize: captureImageData.originalSize,
                cameraTransform: captureImageData.cameraTransform,
                cameraIntrinsics: captureImageData.cameraIntrinsics,
                deviceLocation: deviceLocation
            )
        }
        let coordinates: [[CLLocationCoordinate2D]] = [locationCoordinates]
        let locationDelta = locationDeltas.reduce(SIMD2<Float>(0, 0), +) / Float(locationDeltas.count)
        let lidarDepth = pointDepthValues.reduce(0, +) / Float(pointDepthValues.count)
        return LocationRequestResult(
            coordinates: coordinates, locationDelta: locationDelta, lidarDepth: lidarDepth
        )
    }
    
    private func getLocationFromPolygon(
        depthMapProcessor: DepthMapProcessor,
        localizationProcessor: LocalizationProcessor,
        captureImageData: CaptureImageData,
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> LocationRequestResult {
        let polygonPoints = accessibilityFeature.contourDetails.normalizedPoints
        let leftMostPoint = polygonPoints.min { $0.x < $1.x }
        let rightMostPoint = polygonPoints.max { $0.x < $1.x }
        guard let leftMostPoint, let rightMostPoint else {
            throw AttributeEstimationPipelineError.invalidAttributeData
        }
        let centerPoint = simd_float2(
            x: (leftMostPoint.x + rightMostPoint.x) / 2,
            y: (leftMostPoint.y + rightMostPoint.y) / 2
        )
        let points = [leftMostPoint, centerPoint, rightMostPoint] /// Closing the polygon
        let pointDepthValues = try depthMapProcessor.getFeatureDepthsAtNormalizedPoints(points)
        let pointsWithDepth: [PointWithDepth] = zip(points, pointDepthValues).map {
            return PointWithDepth(point: CGPoint(x: CGFloat($0.0.x), y: CGFloat($0.0.y)), depth: $0.1)
        }
        /// For debugging
        let locationDeltas: [SIMD2<Float>] = pointsWithDepth.map { pointWithDepth in
            return localizationProcessor.calculateDelta(
                point: pointWithDepth.point, depth: pointWithDepth.depth,
                imageSize: captureImageData.originalSize,
                cameraTransform: captureImageData.cameraTransform,
                cameraIntrinsics: captureImageData.cameraIntrinsics
            )
        }
        let locationCoordinates: [CLLocationCoordinate2D] = pointsWithDepth.map { pointWithDepth in
            return localizationProcessor.calculateLocation(
                point: pointWithDepth.point, depth: pointWithDepth.depth,
                imageSize: captureImageData.originalSize,
                cameraTransform: captureImageData.cameraTransform,
                cameraIntrinsics: captureImageData.cameraIntrinsics,
                deviceLocation: deviceLocation
            )
        }
        let coordinates: [[CLLocationCoordinate2D]] = [locationCoordinates]
        let locationDelta = locationDeltas.reduce(SIMD2<Float>(0, 0), +) / Float(locationDeltas.count)
        let lidarDepth = pointDepthValues.reduce(0, +) / Float(pointDepthValues.count)
        return LocationRequestResult(
            coordinates: coordinates, locationDelta: locationDelta, lidarDepth: lidarDepth
        )
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
