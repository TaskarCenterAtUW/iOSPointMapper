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
        let oswEntityClass = accessibilityFeatureClass.oswPolicy.oswElementClass
        /**
         - TODO:
         Streamline this function.
         Currently, it seems like all the 3 functions could be merged into one with minor adjustments.
         */
        if oswEntityClass.geometry == .linestring {
            return try await uploadLineString(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatureClass: accessibilityFeatureClass,
                accessibilityFeatures: accessibilityFeatures,
                mappingData: mappingData,
                accessToken: accessToken
            )
        } else if oswEntityClass.geometry == .polygon {
            return try await uploadPolygon(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatureClass: accessibilityFeatureClass,
                accessibilityFeatures: accessibilityFeatures,
                mappingData: mappingData,
                accessToken: accessToken
            )
        } else {
            return try await uploadNodes(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatureClass: accessibilityFeatureClass,
                accessibilityFeatures: accessibilityFeatures,
                mappingData: mappingData,
                accessToken: accessToken
            )
        }
    }
    
    func uploadCaptureNode(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        mappingData: MappingData,
        accessToken: String
    ) async throws {
        
    }
    
    private func uploadNodes(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        let totalFeatures = accessibilityFeatures.count
        
        var featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol] = [:]
        var featureOSMIdToPointMap: [String: OSWPoint] = [:]
        for feature in accessibilityFeatures {
            let point = featureToPoint(feature)
            guard let point else { continue }
            let osmId = point.id
            featureOSMIdToFeatureMap[osmId] = feature
            featureOSMIdToPointMap[osmId] = point
        }
        let operations: [ChangesetDiffOperation] = featureOSMIdToPointMap.values.map { .create($0) }
        guard !operations.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: operations,
            accessToken: accessToken
        )
        let mappedAccessibilityFeatures = getMappedAccessibilityFeatureFromUploadedElements(
            uploadedElements: uploadedElements,
            featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
            featureOSMIdToPointMap: featureOSMIdToPointMap
        )
        guard !mappedAccessibilityFeatures.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        
        let failedUploads = totalFeatures - mappedAccessibilityFeatures.count
        return APITransmissionResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToPoint(
        _ feature: any AccessibilityFeatureProtocol
    ) -> OSWPoint? {
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
    
    private func getMappedAccessibilityFeatureFromUploadedElements(
        uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol],
        featureOSMIdToPointMap: [String: OSWPoint]
    ) -> [MappedAccessibilityFeature] {
        let accessibilityFeatures: [MappedAccessibilityFeature] = uploadedElements.nodes.compactMap { uploadedNode in
            let uploadedNodeData = uploadedNode.value
            let uploadedNodeOSMOldId = uploadedNodeData.oldId
            guard let matchedFeature = featureOSMIdToFeatureMap[uploadedNodeOSMOldId],
                  let matchedOSWPoint = featureOSMIdToPointMap[uploadedNodeOSMOldId] else {
                return nil
            }
            let oswPoint = OSWPoint(
                id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                oswElementClass: matchedOSWPoint.oswElementClass,
                latitude: matchedOSWPoint.latitude, longitude: matchedOSWPoint.longitude,
                attributeValues: matchedOSWPoint.attributeValues
            )
            return MappedAccessibilityFeature(
                id: matchedFeature.id,
                accessibilityFeature: matchedFeature,
                oswElement: oswPoint
            )
        }
        return accessibilityFeatures
    }
    
    private func uploadLineString(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        var accessibilityFeatures = accessibilityFeatures
        guard accessibilityFeatureClass.oswPolicy.oswElementClass.geometry == .linestring else {
            throw APITransmissionError.featureClassNotLineString(accessibilityFeatureClass)
        }
        guard let firstFeature = accessibilityFeatures.first else {
            return APITransmissionResults(failedFeatureUploads: 0, totalFeatureUploads: 0)
        }
        var totalFeatures = accessibilityFeatures.count
        /// Special case: Sidewalks are uploaded as single line strings
        /// TODO: Generalize this by making this singleton feature part of the OSWElementClass or OSWPolicy
        if accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk {
            accessibilityFeatures = [firstFeature]
            totalFeatures = 1
        }
        
        var featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol] = [:]
        var featureOSMIdToLineStringMap: [String: OSWLineString] = [:]
        for feature in accessibilityFeatures {
            let lineString = featureToLineString(feature)
            guard let lineString else { continue }
            let osmId = lineString.id
            featureOSMIdToFeatureMap[osmId] = feature
            featureOSMIdToLineStringMap[osmId] = lineString
        }
        let operations: [ChangesetDiffOperation] = featureOSMIdToLineStringMap.values.map { .create($0) }
        guard !operations.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: operations,
            accessToken: accessToken
        )
        let mappedAccessibilityFeatures = getMappedAccessibilityFeatureFromUploadedElements(
            uploadedElements: uploadedElements,
            featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
            featureOSMIdToLineStringMap: featureOSMIdToLineStringMap
        )
        guard !mappedAccessibilityFeatures.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        let failedUploads = totalFeatures - mappedAccessibilityFeatures.count
        return APITransmissionResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToLineString(
        _ feature: any AccessibilityFeatureProtocol,
    ) -> OSWLineString? {
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
    
    private func getMappedAccessibilityFeatureFromUploadedElements(
        uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol],
        featureOSMIdToLineStringMap: [String: OSWLineString]
    ) -> [MappedAccessibilityFeature] {
        let accessibilityFeatures: [MappedAccessibilityFeature] = uploadedElements.ways.compactMap { uploadedWay in
            let uploadedWayData = uploadedWay.value
            let uploadedWayOSMOldId = uploadedWayData.oldId
            guard let matchedFeature = featureOSMIdToFeatureMap[uploadedWayOSMOldId],
                  let matchedOSWLineString = featureOSMIdToLineStringMap[uploadedWayOSMOldId] else {
                return nil
            }
            /// First, map the nodes to the points
            let oswPoints: [OSWPoint] = uploadedElements.nodes.compactMap { uploadedNode in
                let uploadedNodeData = uploadedNode.value
                let uploadedNodeOSMOldId = uploadedNodeData.oldId
                guard let matchedOSWPoint = matchedOSWLineString.points.first(where: { point in
                    point.id == uploadedNodeOSMOldId
                }) else {
                    return nil
                }
                return OSWPoint(
                    id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                    oswElementClass: matchedOSWPoint.oswElementClass,
                    latitude: matchedOSWPoint.latitude, longitude: matchedOSWPoint.longitude,
                    attributeValues: matchedOSWPoint.attributeValues
                )
            }
            /// Lastly, create the linestring
            let oswLineString = OSWLineString(
                id: uploadedWayData.newId, version: uploadedWayData.newVersion,
                oswElementClass: matchedOSWLineString.oswElementClass,
                attributeValues: matchedOSWLineString.attributeValues,
                points: oswPoints
            )
            return MappedAccessibilityFeature(
                id: matchedFeature.id,
                accessibilityFeature: matchedFeature,
                oswElement: oswLineString
            )
        }
        return accessibilityFeatures
    }
    
    private func uploadPolygon(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        guard accessibilityFeatureClass.oswPolicy.oswElementClass.geometry == .polygon else {
            throw APITransmissionError.featureClassNotPolygon(accessibilityFeatureClass)
        }
        
        let totalFeatures = accessibilityFeatures.count
        
        var featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol] = [:]
        var featureOSMIdToPolygonMap: [String: OSWPolygon] = [:]
        
        for feature in accessibilityFeatures {
            let polygon = featureToPolygon(feature)
            guard let polygon else { continue }
            let osmId = polygon.id
            featureOSMIdToFeatureMap[osmId] = feature
            featureOSMIdToPolygonMap[osmId] = polygon
        }
        let operations: [ChangesetDiffOperation] = featureOSMIdToPolygonMap.values.map { .create($0) }
        guard !operations.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: operations,
            accessToken: accessToken
        )
        let mappedAccessibilityFeatures = getMappedAccessibilityFeatureFromUploadedElements(
            uploadedElements: uploadedElements,
            featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
            featureOSMIdToPolygonMap: featureOSMIdToPolygonMap
        )
        guard !mappedAccessibilityFeatures.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        
        let failedUploads = totalFeatures - mappedAccessibilityFeatures.count
        return APITransmissionResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToPolygon(
        _ feature: any AccessibilityFeatureProtocol,
    ) -> OSWPolygon? {
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
        let oswPolygon = OSWPolygon(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            members: oswPoints
        )
        return oswPolygon
    }
    
    /**
     - TODO:
     Streamline this function
     */
    private func getMappedAccessibilityFeatureFromUploadedElements(
        uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol],
        featureOSMIdToPolygonMap: [String: OSWPolygon]
    ) -> [MappedAccessibilityFeature] {
        let accessibilityFeatures: [MappedAccessibilityFeature] = uploadedElements.relations.compactMap { uploadedRelation in
            let uploadedRelationData = uploadedRelation.value
            let uploadedRelationOSMOldId = uploadedRelationData.oldId
            guard let matchedFeature = featureOSMIdToFeatureMap[uploadedRelationOSMOldId],
                  let matchedOSWPolygon = featureOSMIdToPolygonMap[uploadedRelationOSMOldId] else {
                return nil
            }
            
            /// First, map the nodes to the points
            let oswPoints: [OSWPoint] = uploadedElements.nodes.compactMap { uploadedNode in
                let uploadedNodeData = uploadedNode.value
                let uploadedNodeOSMOldId = uploadedNodeData.oldId
                guard let matchedOSWMember: any OSWElement = matchedOSWPolygon.members.first(where: { member in
                    member.id == uploadedNodeOSMOldId
                }) else {
                    return nil
                }
                guard let matchedOSWPoint = matchedOSWMember as? OSWPoint else {
                    return nil
                }
                return OSWPoint(
                    id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                    oswElementClass: matchedOSWPoint.oswElementClass,
                    latitude: matchedOSWPoint.latitude, longitude: matchedOSWPoint.longitude,
                    attributeValues: matchedOSWPoint.attributeValues
                )
            }
            
            /// Second, map the ways to the linestrings
            let oswWays: [OSWLineString] = uploadedElements.ways.compactMap { uploadedWay in
                let uploadedWayData = uploadedWay.value
                let uploadedWayOSMOldId = uploadedWayData.oldId
                guard let matchedOSWMember: any OSWElement = matchedOSWPolygon.members.first(where: { member in
                    member.id == uploadedWayOSMOldId
                }) else {
                    return nil
                }
                guard let matchedOSWLineString = matchedOSWMember as? OSWLineString else {
                    return nil
                }
                /// Map the points of the linestring
                let oswPoints: [OSWPoint] = uploadedElements.nodes.compactMap { uploadedNode in
                    let uploadedNodeData = uploadedNode.value
                    let uploadedNodeOSMOldId = uploadedNodeData.oldId
                    guard let matchedOSWPoint = matchedOSWLineString.points.first(where: { point in
                        point.id == uploadedNodeOSMOldId
                    }) else {
                        return nil
                    }
                    return OSWPoint(
                        id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                        oswElementClass: matchedOSWPoint.oswElementClass,
                        latitude: matchedOSWPoint.latitude, longitude: matchedOSWPoint.longitude,
                        attributeValues: matchedOSWPoint.attributeValues
                    )
                }
                let oswLineString = OSWLineString(
                    id: uploadedWayData.newId, version: uploadedWayData.newVersion,
                    oswElementClass: matchedOSWLineString.oswElementClass,
                    attributeValues: matchedOSWLineString.attributeValues,
                    points: oswPoints
                )
                return oswLineString
            }
            
            let oswMembers: [any OSWElement] = oswPoints + oswWays
            
            let oswPolygon = OSWPolygon(
                id: uploadedRelationData.newId, version: uploadedRelationData.newVersion,
                oswElementClass: matchedOSWPolygon.oswElementClass,
                attributeValues: matchedOSWPolygon.attributeValues,
                members: oswMembers
            )
            return MappedAccessibilityFeature(
                id: matchedFeature.id,
                accessibilityFeature: matchedFeature,
                oswElement: oswPolygon
            )
        }
        return accessibilityFeatures
    }
}
