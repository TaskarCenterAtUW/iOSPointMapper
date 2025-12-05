//
//  APITransmissionController.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreLocation

enum APITransmissionError: Error, LocalizedError {
}

class APITransmissionController: ObservableObject {
    func uploadFeatures(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        accessToken: String
    ) async throws -> UploadedElements {
        try await uploadCaptureNode(
            workspaceId: workspaceId, changesetId: changesetId,
            accessibilityFeatureClass: accessibilityFeatureClass,
            accessToken: accessToken
        )
        if accessibilityFeatureClass.isWay {
            return try await uploadWay(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatures: accessibilityFeatures,
                accessToken: accessToken
            )
        } else {
            return try await uploadNodes(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatures: accessibilityFeatures,
                accessToken: accessToken
            )
        }
    }
    
    func uploadCaptureNode(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        accessToken: String
    ) async throws {
        
    }
    
    func uploadNodes(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        accessToken: String
    ) async throws -> UploadedElements {
        var id: Int = 0
        let version: Int = 1
        let featureNodes: [OSMNode] = accessibilityFeatures.compactMap { feature in
            id -= 1
            return featureToNode(feature, id: String(id), version: String(version))
        }
        let nodeOperations: [ChangesetDiffOperation] = featureNodes.map { .create($0) }
        return try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: nodeOperations,
            accessToken: accessToken
        )
    }
    
    func uploadWay(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        accessToken: String
    ) async throws -> UploadedElements {
        guard let firstFeature = accessibilityFeatures.first else {
            return UploadedElements(nodes: [:], ways: [:])
        }
        var id: Int = 0
        let version: Int = 1
        let featureNodes: [OSMNode] = accessibilityFeatures.compactMap { feature in
            id -= 1
            return featureToNode(feature, id: String(id), version: String(version))
        }
        /// Only 1 node per way feature is supported currently
        guard featureNodes.count >= 1, let firstNode = featureNodes.first else {
            return UploadedElements(nodes: [:], ways: [:])
        }
        guard let featureWay = featureToWay(
            firstFeature.accessibilityFeatureClass,
            featureNodes: [firstNode],
            id: String(id),
            version: String(version)
        ) else {
            return UploadedElements(nodes: [:], ways: [:])
        }
        var wayOperations: [ChangesetDiffOperation] = []
        wayOperations.append(.create(firstNode))
        wayOperations.append(.create(featureWay))
        return try await ChangesetService.shared.performUploadAsync(
            workspaceId: workspaceId, changesetId: changesetId,
            operations: wayOperations,
            accessToken: accessToken
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
}
