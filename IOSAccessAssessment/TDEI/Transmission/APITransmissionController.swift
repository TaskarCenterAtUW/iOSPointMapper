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

class APITransmissionController: ObservableObject {
    func uploadFeatures(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        accessToken: String
    ) async throws -> (nodeData: MappingNodeData?, wayData: MappingWayData?) {
        try await uploadCaptureNode(
            workspaceId: workspaceId, changesetId: changesetId,
            accessibilityFeatureClass: accessibilityFeatureClass,
            mappingData: mappingData,
            accessToken: accessToken
        )
        var nodeData: MappingNodeData? = nil
        var wayData: MappingWayData? = nil
        if accessibilityFeatureClass.isWay {
            wayData = try await uploadWay(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatureClass: accessibilityFeatureClass,
                accessibilityFeatures: accessibilityFeatures,
                mappingData: mappingData,
                accessToken: accessToken
            )
        } else {
            nodeData = try await uploadNodes(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatureClass: accessibilityFeatureClass,
                accessibilityFeatures: accessibilityFeatures,
                mappingData: mappingData,
                accessToken: accessToken
            )
        }
        return (nodeData, wayData)
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
    ) async throws -> MappingNodeData? {
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
            return nil
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
            return nil
        }
        return MappingNodeData(nodes: uploadedAccessibilityFeatures)
    }
    
    private func uploadWay(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        accessToken: String
    ) async throws -> MappingWayData? {
        guard accessibilityFeatureClass.isWay else {
            throw APITransmissionError.featureClassNotWay(accessibilityFeatureClass)
        }
        guard let firstFeature = accessibilityFeatures.first else {
            return nil
        }
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
            return nil
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
            return nil
        }
        
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: wayOperations,
            accessToken: accessToken
        )
        guard let uploadedWayData = uploadedElements.ways.first?.value else {
            return nil
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
        return MappingWayData(way: uploadedWay, nodes: uploadedAccessibilityFeatures)
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
