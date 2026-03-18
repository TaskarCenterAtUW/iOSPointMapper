//
//  LocationFromMeshExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/16/26.
//

import SwiftUI
import CoreLocation

extension AttributeEstimationPipeline {
    func getLocationFromMeshForLineStringByPlane(
        depthMapProcessor: DepthMapProcessor,
        localizationProcessor: LocalizationProcessor,
        captureImageData: CaptureImageData,
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature,
        plane: Plane, meshContents: MeshContents
    ) throws -> LocationRequestResult {
        guard let worldPointsProcessor = self.worldPointsProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.worldPointsProcessorKey)
        }
        guard let planeAttributeProcessor = self.planeAttributeProcessor else {
            throw AttributeEstimationPipelineError.configurationError(Constants.Texts.planeAttributeProcessorKey)
        }
        let meshPolygons: [MeshPolygon] = meshContents.polygons
        let worldPointsFromMesh: [WorldPoint] = meshPolygons.map { triangle in
            return WorldPoint(p: triangle.centroid)
        }
        let projectedPoints = try worldPointsProcessor.projectPointsToPlane(
            worldPoints: worldPointsFromMesh, plane: plane,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            imageSize: captureImageData.captureImageDataResults.segmentationLabelImage.extent.size
        )
        let projectedPointBins = try planeAttributeProcessor.binProjectedPoints(projectedPoints: projectedPoints)
        /// Then, get the actual bins from the mesh triangles themselves
        let meshTriangles: [MeshTriangle] = meshContents.triangles
        let meshProjectedPointBins = try planeAttributeProcessor.binMeshTriangles(
            meshTriangles: meshTriangles, initialProjectedPointBins: projectedPointBins,
            plane: plane
        )
        
        let projectedEndpoints: (ProjectedPoint, ProjectedPoint) = try planeAttributeProcessor.getEndpointsFromBins(
            projectedPointBins: meshProjectedPointBins
        )
        var worldEndpoints: [WorldPoint] = try worldPointsProcessor.unprojectPointsFromPlaneCPU(
            projectedPoints: [projectedEndpoints.0, projectedEndpoints.1], plane: plane
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
        let locationElement = OSMLocationElement(coordinates: locationCoordinates, isWay: true, isClosed: false)
        let locationDetails = OSMLocationDetails(locations: [locationElement])
        let locationDelta = locationDeltas.reduce(SIMD2<Float>(0, 0), +) / Float(locationDeltas.count)
        let lidarDepth = locationDeltas.map { simd_length($0) }.reduce(0, +) / Float(locationDeltas.count)
        return LocationRequestResult(
            locationDetails: locationDetails, locationDelta: locationDelta, lidarDepth: lidarDepth
        )
    }
}
