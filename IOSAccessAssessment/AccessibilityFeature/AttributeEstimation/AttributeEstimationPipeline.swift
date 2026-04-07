//
//  AttributeEstimationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreLocation
import MapKit

enum AttributeEstimationPipelineError: Error, LocalizedError {
    case configurationError(String)
    case missingCaptureData
    case missingDepthImage
    case missingPreprocessors
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
        case .missingPreprocessors:
            return NSLocalizedString("Required pre-processors are not configured.", comment: "")
        case .invalidAttributeData:
            return NSLocalizedString("Invalid attribute data encountered.", comment: "")
        case .attributeAssignmentError:
            return NSLocalizedString("Error occurred while assigning attribute value.", comment: "")
        }
    }
}

struct LocationRequestResult: Sendable {
    let locationDetails: OSMLocationDetails
    let locationDelta: SIMD2<Float>
    let lidarDepth: Float
}

enum AttributeEstimationPipelineConstants {
    enum Texts {
        static let depthMapProcessorKey = "Depth Map Processor"
        static let localizationProcessorKey = "Localization Processor"
        static let planeProcessorKey = "Plane Processor"
        static let planeAttributeProcessorKey = "Plane Attribute Processor"
        static let worldPointsProcessorKey = "World Points Processor"
    }
}

/**
    An attribute estimation pipeline that processes editable accessibility features to estimate their attributes.
 */
class AttributeEstimationPipeline: ObservableObject {
    struct PrerequisiteCache: Sendable {
        var worldPoints: [WorldPoint]? = nil
        var worldPointsGrid: WorldPointsGrid? = nil
        var pointAlignedPlane: Plane? = nil
        var meshContents: MeshContents? = nil
        var meshPolygons: [MeshPolygon]? = nil
        var meshTriangles: [MeshTriangle]? = nil
        var meshAlignedPlane: Plane? = nil
    }
    
    var captureImageData: (any CaptureImageDataProtocol)?
    var captureMeshData: (any CaptureMeshDataProtocol)?
    
    var depthMapProcessor: DepthMapProcessor?
    var localizationProcessor: LocalizationProcessor?
    var worldPointsProcessor: WorldPointsProcessor?
    var planeProcessor: PlaneProcessor?
    var planeAttributeProcessor: PlaneAttributeProcessor?
    var damageDetectionPipeline: DamageDetectionPipeline?
    
    var prerequisiteCache = PrerequisiteCache()
    
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
        let worldPointsProcessor = try WorldPointsProcessor()
        self.worldPointsProcessor = worldPointsProcessor
        self.planeProcessor = PlaneProcessor(worldPointsProcessor: worldPointsProcessor)
        self.planeAttributeProcessor = try PlaneAttributeProcessor()
        self.captureImageData = captureImageData
        self.captureMeshData = captureMeshData
        let damageDetectionPipeline = DamageDetectionPipeline()
        try damageDetectionPipeline.configure()
        self.damageDetectionPipeline = damageDetectionPipeline
    }
    
    func setPrerequisites(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws {
        let oswElementClass = accessibilityFeature.accessibilityFeatureClass.oswPolicy.oswElementClass
        let isMeshEnabled: Bool = captureMeshData != nil
        var worldPoints: [WorldPoint]? = nil
        var worldPointsGrid: WorldPointsGrid? = nil
        var pointAlignedPlane: Plane? = nil
        var meshContents: MeshContents? = nil
        var meshPolygons: [MeshPolygon]? = nil
        var meshTriangles: [MeshTriangle]? = nil
        var meshAlignedPlane: Plane? = nil
        switch(oswElementClass) {
        case .Sidewalk:
            if isMeshEnabled {
                meshContents = try self.getMeshContents(accessibilityFeature: accessibilityFeature)
                meshPolygons = meshContents?.polygons
                meshTriangles = meshContents?.triangles
                meshAlignedPlane = try self.calculateAlignedPlane(
                    accessibilityFeature: accessibilityFeature, meshPolygons: meshPolygons
                )
            }
            /// TODO: We can actually, eventually, comment this out since we don't need world points if mesh data is available.
            /// But we will have to ensure that none of the attribute calculations rely on world points in that case, which may require some refactoring, so leaving it for now.
            worldPoints = try self.getWorldPoints(accessibilityFeature: accessibilityFeature)
            worldPointsGrid = try self.getWorldPointsGrid(accessibilityFeature: accessibilityFeature)
            pointAlignedPlane = try self.calculateAlignedPlane(
                accessibilityFeature: accessibilityFeature, worldPoints: worldPoints
            )
        default:
            break
        }
        self.prerequisiteCache.worldPoints = worldPoints
        self.prerequisiteCache.worldPointsGrid = worldPointsGrid
        self.prerequisiteCache.pointAlignedPlane = pointAlignedPlane
        self.prerequisiteCache.meshContents = meshContents
        self.prerequisiteCache.meshPolygons = meshPolygons
        self.prerequisiteCache.meshTriangles = meshTriangles
        self.prerequisiteCache.meshAlignedPlane = meshAlignedPlane
    }
    
    func clearPrerequisites() {
        self.prerequisiteCache.worldPoints = nil
        self.prerequisiteCache.pointAlignedPlane = nil
        self.prerequisiteCache.meshContents = nil
        self.prerequisiteCache.meshPolygons = nil
        self.prerequisiteCache.meshTriangles = nil
        self.prerequisiteCache.meshAlignedPlane = nil
    }
    
    func processLocationRequest(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: EditableAccessibilityFeature
    ) throws {
        let locationRequestResult = try self.calculateLocation(
            deviceLocation: deviceLocation,
            accessibilityFeature: accessibilityFeature
        )
        accessibilityFeature.setLocationDetails(locationDetails: locationRequestResult.locationDetails)
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
    
    func processIsExistingRequest(
        deviceLocation: CLLocationCoordinate2D,
        mappingData: CurrentMappingData,
        accessibilityFeature: EditableAccessibilityFeature
    ) {
        /// Threshold needs to be in Map Units
        let distanceThreshold = Constants.WorkspaceConstants.fetchUpdateRadiusThresholdInMeters * MKMapPointsPerMeterAtLatitude(deviceLocation.latitude)
        guard let osmLocationDetails = accessibilityFeature.locationDetails,
              let nearestElement = mappingData.getNearestFeature(
                  to: osmLocationDetails, featureClass: accessibilityFeature.accessibilityFeatureClass,
                  distanceThreshold: distanceThreshold
              ) else {
            accessibilityFeature.setIsExisting(false)
            return
        }
        let isExisting = accessibilityFeature.accessibilityFeatureClass.oswPolicy.isExistingFirst
        accessibilityFeature.setIsExisting(isExisting)
        accessibilityFeature.setOSWElement(oswElement: nearestElement)
    }
    
    func processAttributeRequest(
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
