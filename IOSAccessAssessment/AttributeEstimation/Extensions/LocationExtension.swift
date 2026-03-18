//
//  LocationExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/25/26.
//
import SwiftUI
import CoreLocation

extension AttributeEstimationPipeline {
    func calculateLocation(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> LocationRequestResult {
        let isMeshEnabled: Bool = self.captureMeshData != nil
        let oswElementClass = accessibilityFeature.accessibilityFeatureClass.oswPolicy.oswElementClass
        switch(oswElementClass) {
        case .Sidewalk:
            if isMeshEnabled {
                return try self.calculateLocationFromMeshForLineString(
                    deviceLocation: deviceLocation,
                    accessibilityFeature: accessibilityFeature
                )
            }
            return try self.calculateLocationFromImageForLineString(
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        case .Building:
            return try self.calculateLocationFromImageForPolygon(
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        default:
            return try self.calculateLocationFromImageForPoint(
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        }
    }
}

/**
 Extension for additional location processing methods.
 */
extension AttributeEstimationPipeline {
    func calculateLocationFromImageForPoint(
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
        return try getLocationFromImageByCentroid(
            depthMapProcessor: depthMapProcessor,
            localizationProcessor: localizationProcessor,
            captureImageData: captureImageDataConcrete,
            deviceLocation: deviceLocation,
            accessibilityFeature: accessibilityFeature
        )
    }
    
    func calculateLocationFromImageForLineString(
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
        let worldPoints = try self.prerequisiteCache.worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        let alignedPlane = try self.prerequisiteCache.pointAlignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, worldPoints: worldPoints
        )
        do {
            return try getLocationFromImageForLineStringByPlane(
                depthMapProcessor: depthMapProcessor,
                localizationProcessor: localizationProcessor,
                captureImageData: captureImageDataConcrete,
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature,
                plane: alignedPlane, worldPoints: worldPoints
            )
        } catch {
            return try getLocationFromImageForLineStringByTrapezoid(
                depthMapProcessor: depthMapProcessor,
                localizationProcessor: localizationProcessor,
                captureImageData: captureImageDataConcrete,
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        }
    }
    
    func calculateLocationFromImageForPolygon(
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
            return try getLocationFromImageByPolygon(
                depthMapProcessor: depthMapProcessor,
                localizationProcessor: localizationProcessor,
                captureImageData: captureImageDataConcrete,
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        } catch {
            return try getLocationFromImageByCentroid(
                depthMapProcessor: depthMapProcessor,
                localizationProcessor: localizationProcessor,
                captureImageData: captureImageDataConcrete,
                deviceLocation: deviceLocation,
                accessibilityFeature: accessibilityFeature
            )
        }
    }
}

extension AttributeEstimationPipeline {
    func calculateLocationFromMeshForLineString(
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
        let meshContents: MeshContents = try self.prerequisiteCache.meshContents ?? self.getMeshContents(
            accessibilityFeature: accessibilityFeature
        )
        let meshPolygons: [MeshPolygon] = self.prerequisiteCache.meshPolygons ?? meshContents.polygons
        let alignedPlane: Plane = try self.prerequisiteCache.meshAlignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, meshPolygons: meshPolygons
        )
        return try getLocationFromMeshForLineStringByPlane(
            depthMapProcessor: depthMapProcessor,
            localizationProcessor: localizationProcessor,
            captureImageData: captureImageDataConcrete,
            deviceLocation: deviceLocation,
            accessibilityFeature: accessibilityFeature,
            plane: alignedPlane, meshContents: meshContents
        )
    }
}
