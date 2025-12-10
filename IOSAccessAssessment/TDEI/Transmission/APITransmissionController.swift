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
    
    init(
        accessibilityFeatures: [MappedAccessibilityFeature],
        failedFeatureUploads: Int = 0, totalFeatureUploads: Int = 0
    ) {
        self.accessibilityFeatures = accessibilityFeatures
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
    }
    
    init(failedFeatureUploads: Int, totalFeatureUploads: Int) {
        self.accessibilityFeatures = nil
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
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
    
    func uploadFeatures(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        idGenerator = IntIdGenerator()
        try await uploadCaptureNode(
            workspaceId: workspaceId, changesetId: changesetId,
            accessibilityFeatureClass: accessibilityFeatureClass,
            mappingData: mappingData,
            accessToken: accessToken
        )
        let transmissionResults = try await uploadMainFeatures(
            workspaceId: workspaceId, changesetId: changesetId,
            accessibilityFeatureClass: accessibilityFeatureClass,
            accessibilityFeatures: accessibilityFeatures,
            mappingData: mappingData,
            accessToken: accessToken
        )
        return transmissionResults
    }
    
    func uploadCaptureNode(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        mappingData: MappingData,
        accessToken: String
    ) async throws {
        
    }
    
    private func uploadMainFeatures(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        /// Handle any special cases depending on the Accessibility Feature Class
        var accessibilityFeatures = accessibilityFeatures
        var totalFeatures = accessibilityFeatures.count
        guard totalFeatures > 0, let firstFeature = accessibilityFeatures.first else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        if accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk {
            accessibilityFeatures = [firstFeature]
            totalFeatures = 1
        }
        
        /// Map Accessibility Features to OSW Elements
        var featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol] = [:]
        var featureOSMIdToOSWElementMap: [String: any OSWElement] = [:]
        var featureToElementFunction: ((any AccessibilityFeatureProtocol) -> (any OSWElement)?)?
        switch accessibilityFeatureClass.oswPolicy.oswElementClass.geometry {
        case .point:
            featureToElementFunction = { self.featureToPoint($0) }
        case .linestring:
            featureToElementFunction = { self.featureToLineString($0) }
        case .polygon:
            featureToElementFunction = { self.featureToPolygon($0) }
        }
        guard let featureToElementFunction else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        for feature in accessibilityFeatures {
            let oswElement = featureToElementFunction(feature)
            guard let oswElement else { continue }
            let osmId = oswElement.id
            featureOSMIdToFeatureMap[osmId] = feature
            featureOSMIdToOSWElementMap[osmId] = oswElement
        }
        
        /// Prepare upload operations from the OSW Elements, and perform upload
        let uploadOperations: [ChangesetDiffOperation] = featureOSMIdToOSWElementMap.values.map { .create($0) }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: uploadOperations,
            accessToken: accessToken
        )
        
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements response
        var uploadedOSWElements: [any OSWElement]
        switch accessibilityFeatureClass.oswPolicy.oswElementClass.geometry {
        case .point:
            let featureToOriginalPointMap: [String: OSWPoint] = featureOSMIdToOSWElementMap.compactMapValues {
                $0 as? OSWPoint
            }
            guard !featureToOriginalPointMap.isEmpty else {
                return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
            }
            uploadedOSWElements = getUploadedOSWPoints(
                from: uploadedElements,
                featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
                featureOSMIdToOriginalPointMap: featureToOriginalPointMap
            )
        case .linestring:
            let featureToOriginalLineStringMap: [String: OSWLineString] = featureOSMIdToOSWElementMap.compactMapValues {
                $0 as? OSWLineString
            }
            guard !featureToOriginalLineStringMap.isEmpty else {
                return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
            }
            uploadedOSWElements = getUploadedOSWLineStrings(
                from: uploadedElements,
                featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
                featureOSMIdToOriginalLineStringMap: featureToOriginalLineStringMap
            )
        case .polygon:
            let featureToOriginalPolygonMap: [String: OSWPolygon] = featureOSMIdToOSWElementMap.compactMapValues {
                $0 as? OSWPolygon
            }
            guard !featureToOriginalPolygonMap.isEmpty else {
                return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
            }
            uploadedOSWElements = getUploadedPolygons(
                from: uploadedElements,
                featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
                featureOSMIdToOriginalPolygonMap: featureToOriginalPolygonMap
            )
        }
        guard !uploadedOSWElements.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        
        /// Created Mapped Accessibility Features from the uploaded OSW Elements
        let mappedAccessibilityFeatures: [MappedAccessibilityFeature] = uploadedOSWElements.compactMap { oswElement in
            let osmId = oswElement.id
            guard let matchedFeature = featureOSMIdToFeatureMap[osmId] else {
                return nil
            }
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
    
    private func featureToPoint(_ feature: any AccessibilityFeatureProtocol) -> OSWPoint? {
        guard let featureLocation = feature.location else {
            return nil
        }
        let oswPoint = OSWPoint(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: feature.accessibilityFeatureClass.oswPolicy.oswElementClass,
            latitude: featureLocation.latitude,
            longitude: featureLocation.longitude,
            attributeValues: feature.attributeValues
        )
        return oswPoint
    }
    
    private func featureToLineString(_ feature: any AccessibilityFeatureProtocol) -> OSWLineString? {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .linestring else {
            return nil
        }
//        var oswPointIds: [String] = []
        var oswPoints: [OSWPoint] = []
        [feature.location].forEach { location in
            guard let location else { return }
            let oswPointId = String(idGenerator.nextId())
//            oswPointIds.append(oswPointId)
            let point = OSWPoint(
                id: oswPointId, version: "1",
                oswElementClass: oswElementClass,
                latitude: location.latitude, longitude: location.longitude,
                attributeValues: [:]
            )
            oswPoints.append(point)
        }
        let oswLineString = OSWLineString(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            points: oswPoints
        )
        return oswLineString
    }
    
    private func featureToPolygon(_ feature: any AccessibilityFeatureProtocol) -> OSWPolygon? {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .polygon else {
            return nil
        }
        
        var oswPoints: [any OSWElement] = []
        [feature.location].forEach { location in
            guard let location else { return }
            let oswPointId = String(idGenerator.nextId())
            let point = OSWPoint(
                id: oswPointId, version: "1",
                oswElementClass: oswElementClass,
                latitude: location.latitude, longitude: location.longitude,
                attributeValues: [:]
            )
            oswPoints.append(point)
        }
        let oswMembers = oswPoints.map {
            /// TODO: Add the exact role of the member
            return OSWRelationMember(element: $0)
        }
        let oswPolygon = OSWPolygon(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            members: oswMembers
        )
        return oswPolygon
    }
    
    private func getUploadedOSWPoints(
        from uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol],
        featureOSMIdToOriginalPointMap: [String: OSWPoint]
    ) -> [OSWPoint] {
        let oswPoints: [OSWPoint] = uploadedElements.nodes.compactMap { uploadedNode in
            let uploadedNodeData = uploadedNode.value
            let uploadedNodeOSMOldId = uploadedNodeData.oldId
            guard let matchedFeature = featureOSMIdToFeatureMap[uploadedNodeOSMOldId],
                  let matchedOriginalOSWPoint = featureOSMIdToOriginalPointMap[uploadedNodeOSMOldId] else {
                return nil
            }
            return OSWPoint(
                id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                oswElementClass: matchedOriginalOSWPoint.oswElementClass,
                latitude: matchedOriginalOSWPoint.latitude, longitude: matchedOriginalOSWPoint.longitude,
                attributeValues: matchedOriginalOSWPoint.attributeValues
            )
        }
        return oswPoints
    }
    
    private func getUploadedOSWLineStrings(
        from uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol],
        featureOSMIdToOriginalLineStringMap: [String: OSWLineString]
    ) -> [OSWLineString] {
        let oswLineStrings: [OSWLineString] = uploadedElements.ways.compactMap { uploadedWay in
            let uploadedWayData = uploadedWay.value
            let uploadedWayOSMOldId = uploadedWayData.oldId
            guard let matchedFeature = featureOSMIdToFeatureMap[uploadedWayOSMOldId],
                  let matchedOriginalOSWLineString = featureOSMIdToOriginalLineStringMap[uploadedWayOSMOldId] else {
                return nil
            }
            /// First, map the nodes to the points
            let featureOSMIdToOriginalPointMap = matchedOriginalOSWLineString.points.map {
                ($0.id, $0)
            }
            let oswPoints: [OSWPoint] = getUploadedOSWPoints(
                from: uploadedElements,
                featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
                featureOSMIdToOriginalPointMap: Dictionary(uniqueKeysWithValues: featureOSMIdToOriginalPointMap)
            )
            /// Lastly, create the linestring
            return OSWLineString(
                id: uploadedWayData.newId, version: uploadedWayData.newVersion,
                oswElementClass: matchedOriginalOSWLineString.oswElementClass,
                attributeValues: matchedOriginalOSWLineString.attributeValues,
                points: oswPoints
            )
        }
        return oswLineStrings
    }
    
    private func getUploadedPolygons(
        from uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol],
        featureOSMIdToOriginalPolygonMap: [String: OSWPolygon]
    ) -> [OSWPolygon] {
        let oswPolygons: [OSWPolygon] = uploadedElements.relations.compactMap { uploadedRelation -> OSWPolygon? in
            let uploadedRelationData = uploadedRelation.value
            let uploadedRelationOSMOldId = uploadedRelationData.oldId
            guard let matchedFeature = featureOSMIdToFeatureMap[uploadedRelationOSMOldId],
                  let matchedOriginalOSWPolygon = featureOSMIdToOriginalPolygonMap[uploadedRelationOSMOldId] else {
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
                featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
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
                featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
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
                members: oswMembers
            )
        }
        return oswPolygons
    }
}
