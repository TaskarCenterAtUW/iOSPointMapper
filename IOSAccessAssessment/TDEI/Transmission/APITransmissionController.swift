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
        classAnnotationOption: AnnotationOption,
        accessibilityFeatures: [AccessibilityFeature],
        accessToken: String
    ) async throws -> UploadedElements {
        try await uploadCaptureNode(
            workspaceId: workspaceId, changesetId: changesetId,
            accessibilityFeatureClass: accessibilityFeatureClass, classAnnotationOption: classAnnotationOption,
            accessToken: accessToken
        )
        guard classAnnotationOption != .classOption(.discard) else { return UploadedElements(nodes: [:], ways: [:]) }
        let featuresToUpload = accessibilityFeatures.filter { feature in
            feature.selectedAnnotationOption != .individualOption(.discard) &&
            feature.accessibilityFeatureClass == accessibilityFeatureClass
        }
        guard !featuresToUpload.isEmpty else { return UploadedElements(nodes: [:], ways: [:]) }
        if accessibilityFeatureClass.isWay {
            return try await uploadWay(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatures: featuresToUpload,
                accessToken: accessToken
            )
        } else {
            return try await uploadNodes(
                workspaceId: workspaceId, changesetId: changesetId,
                accessibilityFeatures: featuresToUpload,
                accessToken: accessToken
            )
        }
    }
    
    func uploadCaptureNode(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatureClass: AccessibilityFeatureClass,
        classAnnotationOption: AnnotationOption,
        accessToken: String
    ) async throws {
        
    }
    
    func uploadNodes(
        workspaceId: String,
        changesetId: String,
        accessibilityFeatures: [AccessibilityFeature],
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
        accessibilityFeatures: [AccessibilityFeature],
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
    
    private func featureToNode(_ feature: AccessibilityFeature, id: String, version: String) -> OSMNode? {
        guard let featureLocation = feature.calculatedLocation else {
            return nil
        }
        var nodeTags: [String: String] = [:]
        /// TODO: Use the correct API schema tag keys
        nodeTags[APIConstants.TagKeys.classKey] = feature.accessibilityFeatureClass.name
        feature.calculatedAttributeValues.forEach { attributeKeyValuePair in
            let attributeKey = attributeKeyValuePair.key
            let attributeTagKey = attributeKey.osmTagKey
            let attributeValue = attributeKeyValuePair.value
            let attributeTagValue = attributeKey.getOSMTagValue(from: attributeValue)
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
