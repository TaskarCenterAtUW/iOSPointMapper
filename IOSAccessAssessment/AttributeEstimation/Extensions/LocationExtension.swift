//
//  LocationExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/25/26.
//
import SwiftUI
import CoreLocation

/**
 Extension for additional location processing methods.
 */
extension AttributeEstimationPipeline {
    func calculateLocationForPoint(
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
    
    func calculateLocationForLineString(
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
    
    func calculateLocationForPolygon(
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
    
    func getLocationFromCentroid(
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
    
    func getLocationFromTrapezoid(
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
    
    func getLocationFromPolygon(
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
