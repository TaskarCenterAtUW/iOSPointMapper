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
        var featureOSMNodeToFeatureMap: [OSMNode: any AccessibilityFeatureProtocol] = [:]
        for feature in accessibilityFeatures {
            id -= 1
            let featureId = feature.id
            let node = featureToNode(feature, id: String(id), version: String(version))
            guard let node else { continue }
            featureOSMNodeToFeatureMap[node] = feature
        }
        let nodeOperations: [ChangesetDiffOperation] = featureOSMNodeToFeatureMap.keys.map { .create($0) }
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
            featureOSMNodeToFeatureMap: featureOSMNodeToFeatureMap
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
        var featureOSMNodeToFeaturePair: (OSMNode, any AccessibilityFeatureProtocol)?
        for feature in accessibilityFeatures {
            id -= 1
            let featureId = feature.id
            let node = featureToNode(feature, id: String(id), version: String(version))
            guard let node else { continue }
            featureOSMNodeToFeaturePair = (node, feature)
            break
        }
        guard let featureOSMNodeToFeaturePair = featureOSMNodeToFeaturePair else {
            return nil
        }
        let featureOSMNodeToFeatureMap: [OSMNode: any AccessibilityFeatureProtocol] = [
            featureOSMNodeToFeaturePair.0: featureOSMNodeToFeaturePair.1
        ]
        
        /// Check if there is an active way feature to append nodes to
        var featureWay: OSMWay
        var wayOperations: [ChangesetDiffOperation] = []
        wayOperations.append(.create(featureOSMNodeToFeaturePair.0))
        if let activeWayData = mappingData.getActiveFeatureWayData(featureClass: accessibilityFeatureClass) {
            featureWay = activeWayData.way
            wayOperations.append(.modify(featureWay))
        } else if let newWay = featureToWay(
            firstFeature.accessibilityFeatureClass,
            featureNodes: [featureOSMNodeToFeaturePair.0],
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
        let uploadedWay = OSMWay(
            id: uploadedWayData.newId, version: uploadedWayData.newVersion,
            tags: featureWay.tags, nodeRefs: featureWay.nodeRefs
        )
        let uploadedAccessibilityFeatures = getUploadedAccessibilityFeaturesFromUploadedNodes(
            uploadedElements: uploadedElements,
            featureOSMNodeToFeatureMap: featureOSMNodeToFeatureMap
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
        featureOSMNodeToFeatureMap: [OSMNode: any AccessibilityFeatureProtocol]
    ) -> [MappedAccessibilityFeature] {
        let accessibilityFeatures: [MappedAccessibilityFeature] = uploadedElements.nodes.compactMap { uploadedElement in
            let uploadedNodeData = uploadedElement.value
            let uploadedNodeOSMOldId = uploadedNodeData.oldId
            guard let matchedOSMNodeFeaturePair = featureOSMNodeToFeatureMap.first(where: { osmNodeFeaturePair in
                osmNodeFeaturePair.key.id == uploadedNodeOSMOldId
            }) else {
                return nil
            }
            let matchedOSMNode = matchedOSMNodeFeaturePair.key
            let matchedFeature = matchedOSMNodeFeaturePair.value
            let osmNode = OSMNode(
                id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                latitude: matchedOSMNode.latitude, longitude: matchedOSMNode.longitude,
                tags: matchedOSMNode.tags
            )
            return MappedAccessibilityFeature(
                id: matchedOSMNodeFeaturePair.value.id,
                accessibilityFeature: matchedOSMNodeFeaturePair.value,
                osmNode: osmNode
            )
        }
        return accessibilityFeatures
    }
}
