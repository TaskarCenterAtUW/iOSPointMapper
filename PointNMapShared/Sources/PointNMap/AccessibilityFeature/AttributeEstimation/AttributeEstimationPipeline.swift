//
//  AttributeEstimationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import Combine
import CoreLocation
import MapKit
import PointNMapShaderTypes

public enum AttributeEstimationPipelineError: Error, LocalizedError {
    case configurationError(String)
    case missingCaptureData
    case missingDepthImage
    case missingPreprocessors
    case invalidAttributeData
    case attributeAssignmentError
    
    public var errorDescription: String? {
        switch self {
        case .configurationError(let missingDetail):
            return NSLocalizedString("Error occurred during pipeline configuration. Details: \(missingDetail)", comment: "")
        case .missingCaptureData:
            return NSLocalizedString("Captured data is missing for processing.", comment: "")
        case .missingDepthImage:
            return NSLocalizedString("Depth image is missing from the capture data.", comment: "")
        case .missingPreprocessors:
            return NSLocalizedString("Required pre-processors are not configured.", comment: "")
        case .invalidAttributeData:
            return NSLocalizedString("Invalid attribute data encountered.", comment: "")
        case .attributeAssignmentError:
            return NSLocalizedString("Error occurred while assigning attribute value.", comment: "")
        }
    }
}

public struct LocationRequestResult: Sendable {
    public let locationDetails: LocationDetails
    public let locationDelta: SIMD2<Float>
    public let lidarDepth: Float
}

public enum AttributeEstimationPipelineConstants {
    public enum Texts {
        public static let depthMapProcessorKey = "Depth Map Processor"
        public static let localizationProcessorKey = "Localization Processor"
        public static let planeProcessorKey = "Plane Processor"
        public static let planeAttributeProcessorKey = "Plane Attribute Processor"
        public static let worldPointsProcessorKey = "World Points Processor"
    }
}

/**
    An attribute estimation pipeline that processes editable accessibility features to estimate their attributes.
 */
public class AttributeEstimationPipeline: ObservableObject {
    public struct PrerequisiteCache: Sendable {
        public var worldPoints: [WorldPoint]? = nil
        public var worldPointsGrid: WorldPointsGrid? = nil
        public var pointAlignedPlane: Plane? = nil
        public var pointProjectedPlane: ProjectedPlane? = nil
        public var meshContents: MeshContents? = nil
        public var meshPolygons: [MeshPolygon]? = nil
        public var meshTriangles: [MeshTriangle]? = nil
        public var meshAlignedPlane: Plane? = nil
        public var meshProjectedPlane: ProjectedPlane? = nil
    }
    
    public var captureImageData: (any CaptureImageDataProtocol)?
    public var captureMeshData: (any CaptureMeshDataProtocol)?
    
    public var depthMapProcessor: DepthMapProcessor?
    public var localizationProcessor: LocalizationProcessor?
    public var worldPointsProcessor: WorldPointsProcessor?
    public var planeProcessor: PlaneProcessor?
    public var planeAttributeProcessor: PlaneAttributeProcessor?
    public var damageDetectionPipeline: DamageDetectionPipeline?
    public var surfaceNormalsProcessor: SurfaceNormalsProcessor?
    public var surfaceIntegrityProcessor: SurfaceIntegrityProcessor?
    
    public var prerequisiteCache = PrerequisiteCache()
    
    /// TODO: MESH PROCESSING: Add mesh data processing components when needed.
    public func configure(
        captureImageData: (any CaptureImageDataProtocol),
        captureMeshData: (any CaptureMeshDataProtocol)?
    ) throws {
        let captureImageDataConcrete = CaptureImageData(captureImageData)
        guard let depthImage = captureImageDataConcrete.depthImage else {
            throw AttributeEstimationPipelineError.missingDepthImage
        }
        self.depthMapProcessor = try DepthMapProcessor(depthImage: depthImage)
        self.localizationProcessor = LocalizationProcessor()
        let worldPointsProcessor = try WorldPointsProcessor()
        self.worldPointsProcessor = worldPointsProcessor
        self.planeProcessor = PlaneProcessor(worldPointsProcessor: worldPointsProcessor)
        self.planeAttributeProcessor = try PlaneAttributeProcessor()
        self.surfaceNormalsProcessor = try SurfaceNormalsProcessor()
        self.surfaceIntegrityProcessor = try SurfaceIntegrityProcessor()
        self.captureImageData = captureImageData
        self.captureMeshData = captureMeshData
        let damageDetectionPipeline = DamageDetectionPipeline()
        try damageDetectionPipeline.configure()
        self.damageDetectionPipeline = damageDetectionPipeline
    }
    
    public func setPrerequisites(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws {
        let oswElementClass = accessibilityFeature.accessibilityFeatureClass.oswPolicy.oswElementClass
        let isMeshEnabled: Bool = captureMeshData != nil
        var worldPoints: [WorldPoint]? = nil
        var worldPointsGrid: WorldPointsGrid? = nil
        var pointAlignedPlane: Plane? = nil
        var pointProjectedPlane: ProjectedPlane? = nil
        var meshContents: MeshContents? = nil
        var meshPolygons: [MeshPolygon]? = nil
        var meshTriangles: [MeshTriangle]? = nil
        var meshAlignedPlane: Plane? = nil
        var meshProjectedPlane: ProjectedPlane? = nil
        switch(oswElementClass) {
        case .Sidewalk:
            if isMeshEnabled {
                meshContents = try self.getMeshContents(accessibilityFeature: accessibilityFeature)
                meshPolygons = meshContents?.polygons
                meshTriangles = meshContents?.triangles
                let calculatedMeshAlignedPlane = try self.calculateAlignedPlane(
                    accessibilityFeature: accessibilityFeature, meshPolygons: meshPolygons
                )
                meshAlignedPlane = calculatedMeshAlignedPlane
                meshProjectedPlane = try self.calculateProjectedPlane(
                    accessibilityFeature: accessibilityFeature, plane: calculatedMeshAlignedPlane
                )
            }
            /// TODO: We can actually, eventually, comment this out since we don't need world points if mesh data is available.
            /// But we will have to ensure that none of the attribute calculations rely on world points in that case, which may require some refactoring, so leaving it for now.
            worldPoints = try self.getWorldPoints(accessibilityFeature: accessibilityFeature)
            worldPointsGrid = try self.getWorldPointsGrid(accessibilityFeature: accessibilityFeature)
            let calculatedPointProjectedPlane = try self.calculateAlignedPlane(
                accessibilityFeature: accessibilityFeature, worldPoints: worldPoints
            )
            pointAlignedPlane = calculatedPointProjectedPlane
            pointProjectedPlane = try self.calculateProjectedPlane(
                accessibilityFeature: accessibilityFeature, plane: calculatedPointProjectedPlane
            )
        default:
            break
        }
        self.prerequisiteCache.worldPoints = worldPoints
        self.prerequisiteCache.worldPointsGrid = worldPointsGrid
        self.prerequisiteCache.pointAlignedPlane = pointAlignedPlane
        self.prerequisiteCache.pointProjectedPlane = pointProjectedPlane
        self.prerequisiteCache.meshContents = meshContents
        self.prerequisiteCache.meshPolygons = meshPolygons
        self.prerequisiteCache.meshTriangles = meshTriangles
        self.prerequisiteCache.meshAlignedPlane = meshAlignedPlane
        self.prerequisiteCache.meshProjectedPlane = meshProjectedPlane
    }
    
    public func clearPrerequisites() {
        self.prerequisiteCache.worldPoints = nil
        self.prerequisiteCache.pointAlignedPlane = nil
        self.prerequisiteCache.meshContents = nil
        self.prerequisiteCache.meshPolygons = nil
        self.prerequisiteCache.meshTriangles = nil
        self.prerequisiteCache.meshAlignedPlane = nil
    }
    
    public func processLocationRequest(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws {
        let locationRequestResult = try self.calculateLocation(
            deviceLocation: deviceLocation,
            accessibilityFeature: accessibilityFeature
        )
        accessibilityFeature.setLocationDetails(locationDetails: locationRequestResult.locationDetails)
        /// Set Lidar Depth as experimental attribute
        if let lidarDepthAttributeValue = AccessibilityFeatureAttribute.lidarDepth.value(
            from: Double(locationRequestResult.lidarDepth)
        ) {
            do {
                try accessibilityFeature.setExperimentalAttributeValue(lidarDepthAttributeValue, for: .lidarDepth)
            } catch {
                print("Error setting lidar depth attribute for feature \(accessibilityFeature.id): \(error.localizedDescription)")
            }
        }
        if let latitudeDeltaAttributeValue = AccessibilityFeatureAttribute.latitudeDelta.value(
            from: Double(locationRequestResult.locationDelta.x)
        ) {
            do {
                try accessibilityFeature.setExperimentalAttributeValue(latitudeDeltaAttributeValue, for: .latitudeDelta)
            } catch {
                print("Error setting latitude delta attribute for feature " +
                      "\(accessibilityFeature.id): \(error.localizedDescription)")
            }
        }
        if let longitudeDeltaAttributeValue = AccessibilityFeatureAttribute.longitudeDelta.value(
            from: Double(locationRequestResult.locationDelta.y)
        ) {
            do {
                try accessibilityFeature.setExperimentalAttributeValue(longitudeDeltaAttributeValue, for: .longitudeDelta)
            } catch {
                print("Error setting longitude delta attribute for feature " +
                      "\(accessibilityFeature.id): \(error.localizedDescription)")
            }
        }
           
    }
    
    public func processIsExistingRequest(
        deviceLocation: CLLocationCoordinate2D,
        mappingData: CurrentMappingData,
        accessibilityFeature: EditableAccessibilityFeature
    ) {
        /// Threshold needs to be in Map Units
        let distanceThreshold = PointNMapConstants.WorkspaceConstants.fetchUpdateRadiusThresholdInMeters * MKMapPointsPerMeterAtLatitude(deviceLocation.latitude)
        guard let LocationDetails = accessibilityFeature.locationDetails else {
            accessibilityFeature.setIsExisting(false)
            return
        }
        let matchedElement: (any OSWElement)? = mappingData.getMatchedFeature(
            to: LocationDetails, featureClass: accessibilityFeature.accessibilityFeatureClass,
            captureId: self.captureImageData?.id,
            distanceThreshold: distanceThreshold
        )
        guard let matchedElement = matchedElement else {
            accessibilityFeature.setIsExisting(false)
            return
        }
        let isExisting = accessibilityFeature.accessibilityFeatureClass.oswPolicy.isExistingFirst
        accessibilityFeature.setIsExisting(isExisting)
        accessibilityFeature.setOSWElement(oswElement: matchedElement)
    }
    
    public func processAttributeRequest(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws {
        var attributeAssignmentFlagError = false
        
        for attribute in accessibilityFeature.accessibilityFeatureClass.attributes {
            do {
                switch attribute {
                case .width:
                    let widthAttributeValue = try self.calculateWidth(
                        accessibilityFeature: accessibilityFeature
                    )
                    try accessibilityFeature.setAttributeValue(widthAttributeValue, for: .width, isCalculated: true)
                case .runningSlope:
                    let runningSlopeAttributeValue = try self.calculateRunningSlope(
                        accessibilityFeature: accessibilityFeature
                    )
                    try accessibilityFeature.setAttributeValue(runningSlopeAttributeValue, for: .runningSlope, isCalculated: true)
                case .crossSlope:
                    let crossSlopeAttributeValue = try self.calculateCrossSlope(
                        accessibilityFeature: accessibilityFeature
                    )
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
                case .widthFromImage:
                    let widthAttributeValue = try self.calculateWidthFromImage(accessibilityFeature: accessibilityFeature)
                    try accessibilityFeature.setAttributeValue(widthAttributeValue, for: .widthFromImage, isCalculated: true)
                case .runningSlopeFromImage:
                    let runningSlopeAttributeValue = try self.calculateRunningSlopeFromImage(accessibilityFeature: accessibilityFeature)
                    try accessibilityFeature.setAttributeValue(runningSlopeAttributeValue, for: .runningSlopeFromImage, isCalculated: true)
                case .crossSlopeFromImage:
                    let crossSlopeAttributeValue = try self.calculateCrossSlopeFromImage(accessibilityFeature: accessibilityFeature)
                    try accessibilityFeature.setAttributeValue(crossSlopeAttributeValue, for: .crossSlopeFromImage, isCalculated: true)
                case .surfaceIntegrity:
                    let surfaceIntegrityAttributeValue = try self.calculateSurfaceIntegrity(
                        accessibilityFeature: accessibilityFeature
                    )
                    try accessibilityFeature.setAttributeValue(
                        surfaceIntegrityAttributeValue, for: .surfaceIntegrity, isCalculated: true
                    )
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
