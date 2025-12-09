//
//  APITransmissionController.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreLocation

enum APITransmissionError: Error, LocalizedError {
    case featureClassNotWay(AccessibilityFeatureClass)
    
    var errorDescription: String? {
        switch self {
        case .featureClassNotWay(let featureClass):
            return "Feature class is not a way: \(featureClass.name)"
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
        if oswEntityClass.geometry == .linestring {
            return try await uploadLineString(
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
        guard accessibilityFeatureClass.oswPolicy.oswElementClass.geometry == .linestring else {
            throw APITransmissionError.featureClassNotWay(accessibilityFeatureClass)
        }
        guard let firstFeature = accessibilityFeatures.first else {
            return APITransmissionResults(failedFeatureUploads: 0, totalFeatureUploads: 0)
        }
        let totalFeatures = 1
        
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
            let oswPoints: [OSWPoint] = uploadedElements.nodes.compactMap { uploadedNode in
                let uploadedNodeData = uploadedNode.value
                let uploadedNodeOSMOldId = uploadedNodeData.oldId
                guard let matchedOSWNode = matchedOSWLineString.points.first(where: { point in
                    point.id == uploadedNodeOSMOldId
                }) else {
                    return nil
                }
                return OSWPoint(
                    id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                    oswElementClass: matchedOSWNode.oswElementClass,
                    latitude: matchedOSWNode.latitude, longitude: matchedOSWNode.longitude,
                    attributeValues: matchedOSWNode.attributeValues
                )
            }
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
}
