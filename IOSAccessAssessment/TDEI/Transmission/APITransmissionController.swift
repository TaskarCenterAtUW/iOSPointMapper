//
//  APITransmissionController.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreLocation

enum APITransmissionError: Error, LocalizedError {
    case featureClassNotLineString(AccessibilityFeatureClass)
    case featureClassNotPolygon(AccessibilityFeatureClass)
    
    var errorDescription: String? {
        switch self {
        case .featureClassNotLineString(let featureClass):
            return "Feature class is not a line string: \(featureClass.name)"
        case .featureClassNotPolygon(let featureClass):
            return "Feature class is not a polygon: \(featureClass.name)"
        }
    }
}

struct APITransmissionResults: @unchecked Sendable {
    let accessibilityFeatures: [MappedAccessibilityFeature]?
    
    let failedFeatureUploads: Int
    let totalFeatureUploads: Int
    
    let isFailedCaptureUpload: Bool
    
    init(
        accessibilityFeatures: [MappedAccessibilityFeature],
        activeFeatures: [MappedAccessibilityFeature]? = nil,
        failedFeatureUploads: Int = 0, totalFeatureUploads: Int = 0,
        isFailedCaptureUpload: Bool = false
    ) {
        self.accessibilityFeatures = accessibilityFeatures
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
        self.isFailedCaptureUpload = isFailedCaptureUpload
    }
    
    init(failedFeatureUploads: Int, totalFeatureUploads: Int) {
        self.accessibilityFeatures = nil
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
        self.isFailedCaptureUpload = false
    }
    
    /// Clone method for overwriting isFailedCaptureUpload
    init(from other: APITransmissionResults, isFailedCaptureUpload: Bool) {
        self.accessibilityFeatures = other.accessibilityFeatures
        self.failedFeatureUploads = other.failedFeatureUploads
        self.totalFeatureUploads = other.totalFeatureUploads
        self.isFailedCaptureUpload = isFailedCaptureUpload
    }
}

class IntIdGenerator {
    private var currentId: Int
    
    init(startingId: Int = 0) {
        self.currentId = startingId
    }
    
    func nextId() -> Int {
        currentId -= 1
        return currentId
    }
}


class APITransmissionController: ObservableObject {
    private var idGenerator: IntIdGenerator = IntIdGenerator()
    public var capturedFrameIds: Set<UUID> = []
    
    func uploadFeatures(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        captureData: CaptureData,
        captureLocation: CLLocationCoordinate2D,
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        idGenerator = IntIdGenerator()
        var isFailedCaptureUpload = false
        if !capturedFrameIds.contains(captureData.id) {
            do {
                try await uploadCapturePoint(
                    workspaceId: workspaceId, changesetId: changesetId,
                    accessibilityFeatureClass: accessibilityFeatureClass,
                    captureData: captureData,
                    captureLocation: captureLocation,
                    mappingData: mappingData,
                    accessToken: accessToken
                )
            } catch {
                /// Leave it up to the caller to handle the failed capture upload
                isFailedCaptureUpload = true
            }
        }
        var apiTransmissionResults: APITransmissionResults
        switch accessibilityFeatureClass.oswPolicy.oswElementClass.geometry {
        case .point:
            apiTransmissionResults = try await uploadPoints(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatureClass: accessibilityFeatureClass,
                accessibilityFeatures: accessibilityFeatures,
                captureData: captureData,
                captureLocation: captureLocation,
                mappingData: mappingData,
                accessToken: accessToken
            )
        case .linestring:
            apiTransmissionResults = try await uploadLineStrings(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatureClass: accessibilityFeatureClass,
                accessibilityFeatures: accessibilityFeatures,
                captureData: captureData,
                captureLocation: captureLocation,
                mappingData: mappingData,
                accessToken: accessToken
            )
        case .polygon:
            apiTransmissionResults = try await uploadPolygons(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatureClass: accessibilityFeatureClass,
                accessibilityFeatures: accessibilityFeatures,
                captureData: captureData,
                captureLocation: captureLocation,
                mappingData: mappingData,
                accessToken: accessToken
            )
        }
        return APITransmissionResults(
            from: apiTransmissionResults,
            isFailedCaptureUpload: isFailedCaptureUpload
        )
    }
    
    func uploadCapturePoint(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        captureData: CaptureData,
        captureLocation: CLLocationCoordinate2D,
        mappingData: MappingData,
        accessToken: String
    ) async throws {
        let additionalTags: [String: String] = [
            APIConstants.TagKeys.captureIdKey: captureData.id.uuidString,
            APIConstants.TagKeys.captureLatitudeKey: String(captureLocation.latitude),
            APIConstants.TagKeys.captureLongitudeKey: String(captureLocation.longitude)
        ]
        let capturePoint: OSWPoint = OSWPoint(
            id: String(idGenerator.nextId()), version: "1",
            oswElementClass: .AppAnchorNode,
            latitude: captureLocation.latitude, longitude: captureLocation.longitude,
            attributeValues: [:],
            experimentalAttributeValues: [:],
            additionalTags: additionalTags
        )
        let uploadOperation: ChangesetDiffOperation = .create(capturePoint)
        _ = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: [uploadOperation],
            accessToken: accessToken
        )
        capturedFrameIds.insert(captureData.id)
    }
    
    private func getAdditionalTags(
        accessibilityFeatureClass: AccessibilityFeatureClass,
        captureData: CaptureData,
        captureLocation: CLLocationCoordinate2D,
        mappingData: MappingData,
    ) -> [String: String] {
        var enhancedAnalysisMode: Bool = false
        switch captureData {
        case .imageData(_):
            enhancedAnalysisMode = false
        case .imageAndMeshData(_):
            enhancedAnalysisMode = true
        }
        return [
            APIConstants.TagKeys.captureIdKey: captureData.id.uuidString,
            APIConstants.TagKeys.captureLatitudeKey: String(captureLocation.latitude),
            APIConstants.TagKeys.captureLongitudeKey: String(captureLocation.longitude),
            APIConstants.TagKeys.enhancedAnalysisModeKey: String(enhancedAnalysisMode)
        ]
    }
}

/**
 Extension for methods to handle points transmission
 */
extension APITransmissionController {
    func uploadPoints(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        captureData: CaptureData,
        captureLocation: CLLocationCoordinate2D,
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        let accessibilityFeatures = accessibilityFeatures
        let totalFeatures = accessibilityFeatures.count
        /// Map Accessibility Features to OSW Elements
        var featureOSMOldIdToFeatureMap: [String: any AccessibilityFeatureProtocol] = [:]
        var featureOSMOldIdToOSWElementMap: [String: any OSWElement] = [:]
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: accessibilityFeatureClass,
            captureData: captureData, captureLocation: captureLocation,
            mappingData: mappingData
        )
        for feature in accessibilityFeatures {
            let oswElement = featureToPoint(feature, additonalTags: additionalTags)
            guard let oswElement else { continue }
            let osmOldId = oswElement.id
            featureOSMOldIdToFeatureMap[osmOldId] = feature
            featureOSMOldIdToOSWElementMap[osmOldId] = oswElement
        }
        /// Prepare upload operations from the OSW Elements, and perform upload
        let uploadOperations: [ChangesetDiffOperation] = featureOSMOldIdToOSWElementMap.values.map { .create($0) }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: uploadOperations,
            accessToken: accessToken
        )
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements response
        let featureToOriginalPointMap: [String: OSWPoint] = featureOSMOldIdToOSWElementMap.compactMapValues {
            $0 as? OSWPoint
        }
        guard !featureToOriginalPointMap.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        let uploadedOSWElements = getUploadedOSWPoints(
            from: uploadedElements,
            featureOSMIdToOriginalPointMap: featureToOriginalPointMap
        )
        guard !uploadedOSWElements.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Created Mapped Accessibility Features from the uploaded OSW Elements
        /// Make sure you are using the old ids of the uploaded elements to map back to the features
        let uploadedOldToNewIdMap: [String: String] = uploadedElements.oldToNewIdMap
        let mappedAccessibilityFeatures: [MappedAccessibilityFeature] = uploadedOSWElements.compactMap { oswElement in
            let osmNewId = oswElement.id
            guard let osmOldId = uploadedOldToNewIdMap.first(where: { $0.value == osmNewId })?.key else { return nil }
            guard let matchedFeature = featureOSMOldIdToFeatureMap[osmOldId] else { return nil }
            return MappedAccessibilityFeature(
                id: matchedFeature.id,
                accessibilityFeature: matchedFeature,
                oswElement: oswElement
            )
        }
        let failedUploads = totalFeatures - mappedAccessibilityFeatures.count
        return APITransmissionResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToPoint(
        _ feature: any AccessibilityFeatureProtocol,
        additonalTags: [String: String] = [:]
    ) -> OSWPoint? {
        guard let featureLocation = feature.getLastLocationCoordinate() else {
            return nil
        }
        let oswPoint = OSWPoint(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: feature.accessibilityFeatureClass.oswPolicy.oswElementClass,
            latitude: featureLocation.latitude,
            longitude: featureLocation.longitude,
            attributeValues: feature.attributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            additionalTags: additonalTags
        )
        return oswPoint
    }
    
    private func getUploadedOSWPoints(
        from uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToOriginalPointMap: [String: OSWPoint]
    ) -> [OSWPoint] {
        let oswPoints: [OSWPoint] = uploadedElements.nodes.compactMap { uploadedNode in
            let uploadedNodeData = uploadedNode.value
            let uploadedNodeOSMOldId = uploadedNodeData.oldId
            guard let matchedOriginalOSWPoint = featureOSMIdToOriginalPointMap[uploadedNodeOSMOldId] else {
                return nil
            }
            return OSWPoint(
                id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                oswElementClass: matchedOriginalOSWPoint.oswElementClass,
                latitude: matchedOriginalOSWPoint.latitude, longitude: matchedOriginalOSWPoint.longitude,
                attributeValues: matchedOriginalOSWPoint.attributeValues,
                experimentalAttributeValues: matchedOriginalOSWPoint.experimentalAttributeValues,
                additionalTags: matchedOriginalOSWPoint.additionalTags
            )
        }
        return oswPoints
    }
}

/**
 Extension to handle line string transmission
 */
extension APITransmissionController {
    func uploadLineStrings(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        captureData: CaptureData,
        captureLocation: CLLocationCoordinate2D,
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        var accessibilityFeatures = accessibilityFeatures
        var totalFeatures = accessibilityFeatures.count
        guard totalFeatures > 0, let firstFeature = accessibilityFeatures.first else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// For the sidewalk feature class, only upload one linestring representing the entire sidewalk
        if accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk {
            accessibilityFeatures = [firstFeature]
            totalFeatures = 1
        }
        /// Map Accessibility Features to OSW Elements
        var featureOSMOldIdToFeatureMap: [String: any AccessibilityFeatureProtocol] = [:]
        var featureOSMOldIdToOSWElementMap: [String: any OSWElement] = [:]
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: accessibilityFeatureClass,
            captureData: captureData, captureLocation: captureLocation,
            mappingData: mappingData
        )
        for feature in accessibilityFeatures {
            let oswElement = featureToLineString(feature, additonalTags: additionalTags)
            guard let oswElement else { continue }
            let osmOldId = oswElement.id
            featureOSMOldIdToFeatureMap[osmOldId] = feature
            featureOSMOldIdToOSWElementMap[osmOldId] = oswElement
        }
        /// Prepare upload operations from the OSW Elements, and perform upload
        var uploadOperations: [ChangesetDiffOperation] = featureOSMOldIdToOSWElementMap.values.map { .create($0) }
        /// For the sidewalk class, get the previously uploaded linestring, connect it to the new linestring, and add a modify operation
        if accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk,
           let existingMappedFeature = mappingData.featuresMap[accessibilityFeatureClass]?.last {
            let existingOSWElement = existingMappedFeature.oswElement
            if var existingOSWLineString = existingOSWElement as? OSWLineString,
               let newOSWLineString = featureOSMOldIdToOSWElementMap.first?.value as? OSWLineString,
               let newOSWStartingPoint = newOSWLineString.points.first {
                existingOSWLineString.points.append(newOSWStartingPoint)
                featureOSMOldIdToFeatureMap[existingOSWLineString.id] = existingMappedFeature
                featureOSMOldIdToOSWElementMap[existingOSWLineString.id] = existingOSWLineString
                totalFeatures += 1
                uploadOperations.append(.modify(existingOSWLineString))
            }
        }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: uploadOperations,
            accessToken: accessToken
        )
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements response
        let featureToOriginalLineStringMap: [String: OSWLineString] = featureOSMOldIdToOSWElementMap.compactMapValues {
            $0 as? OSWLineString
        }
        guard !featureToOriginalLineStringMap.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        let uploadedOSWElements = getUploadedOSWLineStrings(
            from: uploadedElements,
            featureOSMIdToOriginalLineStringMap: featureToOriginalLineStringMap
        )
        guard !uploadedOSWElements.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Created Mapped Accessibility Features from the uploaded OSW Elements
        /// Make sure you are using the old ids of the uploaded elements to map back to the features
        let uploadedOldToNewIdMap: [String: String] = uploadedElements.oldToNewIdMap
        let mappedAccessibilityFeatures: [MappedAccessibilityFeature] = uploadedOSWElements.compactMap { oswElement in
            let osmNewId = oswElement.id
            guard let osmOldId = uploadedOldToNewIdMap.first(where: { $0.value == osmNewId })?.key else { return nil }
            guard let matchedFeature = featureOSMOldIdToFeatureMap[osmOldId] else { return nil }
            return MappedAccessibilityFeature(
                id: matchedFeature.id,
                accessibilityFeature: matchedFeature,
                oswElement: oswElement
            )
        }
        let failedUploads = totalFeatures - mappedAccessibilityFeatures.count
        return APITransmissionResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToLineString(
        _ feature: any AccessibilityFeatureProtocol,
        additonalTags: [String: String] = [:]
    ) -> OSWLineString? {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .linestring else {
            return nil
        }
//        var oswPointIds: [String] = []
        var oswPoints: [OSWPoint] = []
        guard let featureLocations: [CLLocationCoordinate2D] = feature.locationDetails?.coordinates.first else {
            return nil
        }
        featureLocations.forEach { location in
            let oswPointId = String(idGenerator.nextId())
//            oswPointIds.append(oswPointId)
            let point = OSWPoint(
                id: oswPointId, version: "1",
                oswElementClass: oswElementClass,
                latitude: location.latitude, longitude: location.longitude,
                attributeValues: [:],
                experimentalAttributeValues: [:],
            )
            oswPoints.append(point)
        }
        let oswLineString = OSWLineString(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            points: oswPoints,
            additionalTags: additonalTags
        )
        return oswLineString
    }
    
    private func getUploadedOSWLineStrings(
        from uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToOriginalLineStringMap: [String: OSWLineString]
    ) -> [OSWLineString] {
        let oswLineStrings: [OSWLineString] = uploadedElements.ways.compactMap { uploadedWay in
            let uploadedWayData = uploadedWay.value
            let uploadedWayOSMOldId = uploadedWayData.oldId
            guard let matchedOriginalOSWLineString = featureOSMIdToOriginalLineStringMap[uploadedWayOSMOldId] else {
                return nil
            }
            /// First, map the nodes to the points
            let featureOSMIdToOriginalPointMap = matchedOriginalOSWLineString.points.map {
                ($0.id, $0)
            }
            let oswPoints: [OSWPoint] = getUploadedOSWPoints(
                from: uploadedElements,
                featureOSMIdToOriginalPointMap: Dictionary(uniqueKeysWithValues: featureOSMIdToOriginalPointMap)
            )
            /// Lastly, create the linestring
            return OSWLineString(
                id: uploadedWayData.newId, version: uploadedWayData.newVersion,
                oswElementClass: matchedOriginalOSWLineString.oswElementClass,
                attributeValues: matchedOriginalOSWLineString.attributeValues,
                experimentalAttributeValues: matchedOriginalOSWLineString.experimentalAttributeValues,
                points: oswPoints,
                additionalTags: matchedOriginalOSWLineString.additionalTags
            )
        }
        return oswLineStrings
    }
}

/**
 Extension to handle polygon transmission
 */
extension APITransmissionController {
    func uploadPolygons(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        captureData: CaptureData,
        captureLocation: CLLocationCoordinate2D,
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        let accessibilityFeatures = accessibilityFeatures
        let totalFeatures = accessibilityFeatures.count
        /// Map Accessibility Features to OSW Elements
        var featureOSMOldIdToFeatureMap: [String: any AccessibilityFeatureProtocol] = [:]
        var featureOSMOldIdToOSWElementMap: [String: any OSWElement] = [:]
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: accessibilityFeatureClass,
            captureData: captureData, captureLocation: captureLocation,
            mappingData: mappingData
        )
        for feature in accessibilityFeatures {
            let oswElement = featureToPolygon(feature, additonalTags: additionalTags)
            guard let oswElement else { continue }
            let osmOldId = oswElement.id
            featureOSMOldIdToFeatureMap[osmOldId] = feature
            featureOSMOldIdToOSWElementMap[osmOldId] = oswElement
        }
        /// Prepare upload operations from the OSW Elements, and perform upload
        let uploadOperations: [ChangesetDiffOperation] = featureOSMOldIdToOSWElementMap.values.map { .create($0) }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: uploadOperations,
            accessToken: accessToken
        )
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements response
        let featureToOriginalPolygonMap: [String: OSWPolygon] = featureOSMOldIdToOSWElementMap.compactMapValues {
            $0 as? OSWPolygon
        }
        guard !featureToOriginalPolygonMap.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        let uploadedOSWElements = getUploadedPolygons(
            from: uploadedElements,
            featureOSMIdToOriginalPolygonMap: featureToOriginalPolygonMap
        )
        guard !uploadedOSWElements.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Created Mapped Accessibility Features from the uploaded OSW Elements
        /// Make sure you are using the old ids of the uploaded elements to map back to the features
        let uploadedOldToNewIdMap: [String: String] = uploadedElements.oldToNewIdMap
        let mappedAccessibilityFeatures: [MappedAccessibilityFeature] = uploadedOSWElements.compactMap { oswElement in
            let osmNewId = oswElement.id
            guard let osmOldId = uploadedOldToNewIdMap.first(where: { $0.value == osmNewId })?.key else { return nil }
            guard let matchedFeature = featureOSMOldIdToFeatureMap[osmOldId] else { return nil }
            return MappedAccessibilityFeature(
                id: matchedFeature.id,
                accessibilityFeature: matchedFeature,
                oswElement: oswElement
            )
        }
        let failedUploads = totalFeatures - mappedAccessibilityFeatures.count
        return APITransmissionResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToPolygon(
        _ feature: any AccessibilityFeatureProtocol,
        additonalTags: [String: String] = [:]
    ) -> OSWPolygon? {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .polygon else {
            return nil
        }
        
        var oswElements: [any OSWElement] = []
        guard let featureLocationArrays: [[CLLocationCoordinate2D]] = feature.locationDetails?.coordinates,
              let firstLocationArray = featureLocationArrays.first, !firstLocationArray.isEmpty else {
            return nil
        }
        featureLocationArrays.forEach { locationArray in
            guard !locationArray.isEmpty else { return }
            var oswPoints: [OSWPoint] = []
            locationArray.forEach { location in
                let oswPointId = String(idGenerator.nextId())
                let point = OSWPoint(
                    id: oswPointId, version: "1",
                    oswElementClass: oswElementClass,
                    latitude: location.latitude, longitude: location.longitude,
                    attributeValues: [:],
                    experimentalAttributeValues: [:]
                )
                oswPoints.append(point)
            }
            if locationArray.count <= 2 {
                oswElements.append(contentsOf: oswPoints)
            } else {
                let oswLineString = OSWLineString(
                    id: String(idGenerator.nextId()),
                    version: "1",
                    oswElementClass: oswElementClass,
                    attributeValues: [:],
                    experimentalAttributeValues: [:],
                    points: oswPoints
                )
                oswElements.append(oswLineString)
            }
        }
        let oswMembers = oswElements.map {
            /// TODO: Add the exact role of the member
            return OSWRelationMember(element: $0)
        }
        let oswPolygon = OSWPolygon(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            additionalTags: additonalTags,
            members: oswMembers
        )
        return oswPolygon
    }
    
    private func getUploadedPolygons(
        from uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToOriginalPolygonMap: [String: OSWPolygon]
    ) -> [OSWPolygon] {
        let oswPolygons: [OSWPolygon] = uploadedElements.relations.compactMap { uploadedRelation -> OSWPolygon? in
            let uploadedRelationData = uploadedRelation.value
            let uploadedRelationOSMOldId = uploadedRelationData.oldId
            guard let matchedOriginalOSWPolygon = featureOSMIdToOriginalPolygonMap[uploadedRelationOSMOldId] else {
                return nil
            }
            /// First, map the nodes to the points
            let featureOSMIdToOriginalPointMap = matchedOriginalOSWPolygon.members.compactMap { member -> OSWPoint? in
                let element = member.element
                guard let point = element as? OSWPoint else { return nil }
                return point
            }.reduce(into: [:]) { result, entry in
                result[entry.id] = entry
            }
            let oswPoints: [OSWPoint] = getUploadedOSWPoints(
                from: uploadedElements,
                featureOSMIdToOriginalPointMap: featureOSMIdToOriginalPointMap
            )
            /// Second, map the ways to the linestrings
            let featureOSMIdToOriginalLineStringMap = matchedOriginalOSWPolygon.members.compactMap { member -> OSWLineString? in
                let element = member.element
                guard let lineString = element as? OSWLineString else { return nil }
                return lineString
            }.reduce(into: [:]) { result, entry in
                result[entry.id] = entry
            }
            let oswLineStrings: [OSWLineString] = getUploadedOSWLineStrings(
                from: uploadedElements,
                featureOSMIdToOriginalLineStringMap: featureOSMIdToOriginalLineStringMap
            )
            /// Lastly, create the polygon
            let oswElements: [any OSWElement] = oswPoints + oswLineStrings
            let oswMembers: [OSWRelationMember] = oswElements.map {
                OSWRelationMember(element: $0)
            }
            return OSWPolygon(
                id: uploadedRelationData.newId, version: uploadedRelationData.newVersion,
                oswElementClass: matchedOriginalOSWPolygon.oswElementClass,
                attributeValues: matchedOriginalOSWPolygon.attributeValues,
                experimentalAttributeValues: matchedOriginalOSWPolygon.experimentalAttributeValues,
                additionalTags: matchedOriginalOSWPolygon.additionalTags,
                members: oswMembers,
            )
        }
        return oswPolygons
    }
}
