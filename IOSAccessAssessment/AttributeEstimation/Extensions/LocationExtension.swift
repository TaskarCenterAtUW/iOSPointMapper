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
        accessibilityFeature: EditableAccessibilityFeature,
        alignedPlane: Plane? = nil, worldPoints: [WorldPoint]? = nil
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
            if let alignedPlane, let worldPoints {
                return try getLocationForLineStringFromPlane(
                    depthMapProcessor: depthMapProcessor,
                    localizationProcessor: localizationProcessor,
                    captureImageData: captureImageDataConcrete,
                    deviceLocation: deviceLocation,
                    accessibilityFeature: accessibilityFeature,
                    plane: alignedPlane, worldPoints: worldPoints
                )
            } else {
                return try getLocationFromTrapezoid(
                    depthMapProcessor: depthMapProcessor,
                    localizationProcessor: localizationProcessor,
                    captureImageData: captureImageDataConcrete,
                    deviceLocation: deviceLocation,
                    accessibilityFeature: accessibilityFeature
                )
            }
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
    
    func getLocationForLineStringFromPlane(
        depthMapProcessor: DepthMapProcessor,
        localizationProcessor: LocalizationProcessor,
        captureImageData: CaptureImageData,
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature,
        plane: Plane, worldPoints: [WorldPoint]
    ) throws -> LocationRequestResult {
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.worldPointsProcessorKey)
        }
        guard let planeAttributeProcessor = self.planeAttributeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeAttributeProcessorKey)
        }
        let projectedPoints: [ProjectedPoint] = try worldPointsProcessor.projectPointsToPlane(
            worldPoints: worldPoints, plane: plane,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
        )
        let projectedPointBins: ProjectedPointBins = try planeAttributeProcessor.binProjectedPoints(projectedPoints: projectedPoints)
        let projectedEndpoints: (ProjectedPoint, ProjectedPoint) = try planeAttributeProcessor.getEndpointsFromBins(
            projectedPointBins: projectedPointBins
        )
        var worldEndpoints: [WorldPoint] = try worldPointsProcessor.unprojectPointsFromPlaneCPU(
            projectedPoints: [projectedEndpoints.0, projectedEndpoints.1], plane: plane,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
        )
        var locationDeltas: [SIMD2<Float>] = worldEndpoints.map { worldEndpoint in
            return localizationProcessor.calculateDelta(
                worldPoint: SIMD3<Float>(worldEndpoint.p.x, worldEndpoint.p.y, worldEndpoint.p.z),
                cameraTransform: captureImageData.cameraTransform,
            )
        }
        /// Sort world endpoints based on location deltas  by distance from the camera, so that the closer endpoint is used as the first location for the line string. This is a heuristic to improve location accuracy, especially for longer line strings where depth estimation can be noisier.
        let sortedEndpointsWithDeltas = zip(worldEndpoints, locationDeltas).sorted { simd_length($0.1) < simd_length($1.1) }
        worldEndpoints = sortedEndpointsWithDeltas.map { $0.0 }
        locationDeltas = sortedEndpointsWithDeltas.map { $0.1 }
        let locationCoordinates: [CLLocationCoordinate2D] = worldEndpoints.map { worldEndpoint in
            return localizationProcessor.calculateLocation(
                worldPoint: SIMD3<Float>(worldEndpoint.p.x, worldEndpoint.p.y, worldEndpoint.p.z),
                cameraTransform: captureImageData.cameraTransform,
                deviceLocation: deviceLocation
            )
        }
        let coordinates: [[CLLocationCoordinate2D]] = [locationCoordinates]
        let locationDelta = locationDeltas.reduce(SIMD2<Float>(0, 0), +) / Float(locationDeltas.count)
        let lidarDepth = locationDeltas.map { simd_length($0) }.reduce(0, +) / Float(locationDeltas.count)
        return LocationRequestResult(
            coordinates: coordinates, locationDelta: locationDelta, lidarDepth: lidarDepth
        )
    }
    
    func getLocationFromTrapezoid(
        depthMapProcessor: DepthMapProcessor,
        localizationProcessor: LocalizationProcessor,
        captureImageData: CaptureImageData,
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> LocationRequestResult {
        guard let trapezoidBoundPoints = accessibilityFeature.contourDetails.trapezoidPoints,
              trapezoidBoundPoints.count == 4 else {
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
