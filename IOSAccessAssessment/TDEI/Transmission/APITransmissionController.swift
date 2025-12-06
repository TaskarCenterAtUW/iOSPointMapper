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
    let nodeData: MappingNodeData?
    let wayData: MappingWayData?
    
    let failedFeatureUploads: Int
    let totalFeatureUploads: Int
    
    init(
        nodeData: MappingNodeData? = nil, wayData: MappingWayData? = nil,
        failedFeatureUploads: Int = 0, totalFeatureUploads: Int = 0
    ) {
        self.nodeData = nodeData
        self.wayData = wayData
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
    }
    
    init(failedFeatureUploads: Int, totalFeatureUploads: Int) {
        self.nodeData = nil
        self.wayData = nil
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
    }
}

class APITransmissionController: ObservableObject {
    func uploadFeatures(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        try await uploadCaptureNode(
            workspaceId: workspaceId, changesetId: changesetId,
            accessibilityFeatureClass: accessibilityFeatureClass,
            mappingData: mappingData,
            accessToken: accessToken
        )
        if accessibilityFeatureClass.isWay {
            return try await uploadWay(
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
        
        var id: Int = 0
        let version: Int = 1
        var featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol] = [:]
        var featureOSMIdToNodeMap: [String: OSMNode] = [:]
        for feature in accessibilityFeatures {
            id -= 1
            let osmId = String(id)
            let osmVersion = String(version)
            let node = featureToNode(feature, id: osmId, version: osmVersion)
            guard let node else { continue }
            featureOSMIdToFeatureMap[osmId] = feature
            featureOSMIdToNodeMap[osmId] = node
        }
        let nodeOperations: [ChangesetDiffOperation] = featureOSMIdToNodeMap.values.map { .create($0) }
        guard !nodeOperations.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: nodeOperations,
            accessToken: accessToken
        )
        let uploadedAccessibilityFeatures = getUploadedAccessibilityFeaturesFromUploadedNodes(
            uploadedElements: uploadedElements,
            featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
            featureOSMIdToNodeMap: featureOSMIdToNodeMap
        )
        guard !uploadedAccessibilityFeatures.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        
        let failedUploads = totalFeatures - uploadedAccessibilityFeatures.count
        let nodeData = MappingNodeData(nodes: uploadedAccessibilityFeatures)
        return APITransmissionResults(
            nodeData: nodeData, failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func uploadWay(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        accessToken: String
    ) async throws -> APITransmissionResults {
        guard accessibilityFeatureClass.isWay else {
            throw APITransmissionError.featureClassNotWay(accessibilityFeatureClass)
        }
        guard let firstFeature = accessibilityFeatures.first else {
            return APITransmissionResults(failedFeatureUploads: 0, totalFeatureUploads: 0)
        }
        let totalFeatures = 1
        
        var id: Int = 0
        let version: Int = 1
        var featureOSMIdToFeaturePair: (String, any AccessibilityFeatureProtocol)?
        var featureOSMIdToNodePair: (String, OSMNode)?
        for feature in accessibilityFeatures {
            id -= 1
            let osmId = String(id)
            let osmVersion = String(version)
            let node = featureToNode(feature, id: osmId, version: osmVersion)
            guard let node else { continue }
            featureOSMIdToFeaturePair = (osmId, feature)
            featureOSMIdToNodePair = (osmId, node)
            break
        }
        guard let featureOSMIdToFeaturePair = featureOSMIdToFeaturePair,
              let featureOSMIdToNodePair = featureOSMIdToNodePair else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        let featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol] = [
            featureOSMIdToFeaturePair.0: featureOSMIdToFeaturePair.1
        ]
        let featureOSMIdToNodeMap: [String: OSMNode] = [
            featureOSMIdToNodePair.0: featureOSMIdToNodePair.1
        ]
        
        /// Check if there is an active way feature to append nodes to
        var featureWay: OSMWay
        var featureWayCurrentNodeRefs: [String] = []
        var wayOperations: [ChangesetDiffOperation] = []
        wayOperations.append(.create(featureOSMIdToNodePair.1))
        id -= 1
        if let activeWayData = mappingData.getActiveFeatureWayData(accessibilityFeatureClass: accessibilityFeatureClass) {
            featureWay = activeWayData.way
            featureWayCurrentNodeRefs = featureWay.nodeRefs
            featureWay.nodeRefs.append(featureOSMIdToNodePair.1.id)
            wayOperations.append(.modify(featureWay))
        } else if let newWay = featureToWay(
            firstFeature.accessibilityFeatureClass,
            featureNodes: [featureOSMIdToNodePair.1],
            id: String(id),
            version: String(version)
        ) {
            featureWay = newWay
            wayOperations.append(.create(featureWay))
        } else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: wayOperations,
            accessToken: accessToken
        )
        guard let uploadedWayData = uploadedElements.ways.first?.value else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        let uploadedAccessibilityFeatures = getUploadedAccessibilityFeaturesFromUploadedNodes(
            uploadedElements: uploadedElements,
            featureOSMIdToFeatureMap: featureOSMIdToFeatureMap,
            featureOSMIdToNodeMap: featureOSMIdToNodeMap
        )
        var uploadedNodeRefs: [String] = featureWayCurrentNodeRefs
        uploadedNodeRefs.append(contentsOf: uploadedAccessibilityFeatures.map { $0.osmNode.id })
        let uploadedWay = OSMWay(
            id: uploadedWayData.newId, version: uploadedWayData.newVersion,
            tags: featureWay.tags, nodeRefs: uploadedNodeRefs
        )
        
        let failedUploads = totalFeatures - uploadedAccessibilityFeatures.count
        let wayData = MappingWayData(way: uploadedWay, nodes: uploadedAccessibilityFeatures)
        return APITransmissionResults(
            wayData: wayData, failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToNode(_ feature: any AccessibilityFeatureProtocol, id: String, version: String) -> OSMNode? {
        guard let featureLocation = feature.location else {
            return nil
        }
        var nodeTags: [String: String] = [:]
        /// TODO: Use the correct API schema tag keys
        nodeTags[APIConstants.TagKeys.classKey] = feature.accessibilityFeatureClass.name
        feature.attributeValues.forEach { attributeKeyValuePair in
            let attributeKey = attributeKeyValuePair.key
            let attributeTagKey = attributeKey.osmTagKey
            let attributeValue = attributeKeyValuePair.value
            let attributeTagValue = attributeKey.getOSMTagFromValue(attributeValue: attributeValue)
            guard let attributeTagValue else { return }
            nodeTags[attributeTagKey] = attributeTagValue
        }
        let node = OSMNode(
            id: id,
            version: version,
            latitude: featureLocation.latitude,
            longitude: featureLocation.longitude,
            tags: nodeTags
        )
        return node
    }
    
    private func featureToWay(
        _ featureClass: AccessibilityFeatureClass,
        featureNodes: [OSMNode],
        id: String, version: String
    ) -> OSMWay? {
        guard featureClass.isWay else {
            return nil
        }
        var wayTags: [String: String] = [:]
        wayTags[APIConstants.TagKeys.classKey] = featureClass.name
        let nodeRefs: [String] = featureNodes.map { $0.id }
        let way = OSMWay(
            id: id,
            version: version,
            tags: wayTags,
            nodeRefs: nodeRefs
        )
        return way
    }
    
    private func getUploadedAccessibilityFeaturesFromUploadedNodes(
        uploadedElements: UploadedOSMResponseElements,
        featureOSMIdToFeatureMap: [String: any AccessibilityFeatureProtocol],
        featureOSMIdToNodeMap: [String: OSMNode]
    ) -> [MappedAccessibilityFeature] {
        let accessibilityFeatures: [MappedAccessibilityFeature] = uploadedElements.nodes.compactMap { uploadedElement in
            let uploadedNodeData = uploadedElement.value
            let uploadedNodeOSMOldId = uploadedNodeData.oldId
            guard let matchedOSMIdFeaturePair = featureOSMIdToFeatureMap.first(where: { osmIdFeaturePair in
                osmIdFeaturePair.key == uploadedNodeOSMOldId
            }) else {
                return nil
            }
//            let matchedOSMId = matchedOSMIdFeaturePair.key
            let matchedFeature = matchedOSMIdFeaturePair.value
            guard let matchedOSMNode = featureOSMIdToNodeMap[uploadedNodeOSMOldId] else {
                return nil
            }
            let osmNode = OSMNode(
                id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                latitude: matchedOSMNode.latitude, longitude: matchedOSMNode.longitude,
                tags: matchedOSMNode.tags
            )
            return MappedAccessibilityFeature(
                id: matchedFeature.id,
                accessibilityFeature: matchedFeature,
                osmNode: osmNode
            )
        }
        return accessibilityFeatures
    }
}
