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
        accessibilityFeatureClass: AccessibilityFeatureClass,
        classAnnotationOption: AnnotationOption,
        accessibilityFeatures: [AccessibilityFeature]
    ) throws {
        try uploadCaptureNode(
            accessibilityFeatureClass: accessibilityFeatureClass,
            classAnnotationOption: classAnnotationOption
        )
        guard classAnnotationOption != .classOption(.discard) else { return }
        let featuresToUpload = accessibilityFeatures.filter { feature in
            feature.selectedAnnotationOption != .individualOption(.discard) &&
            feature.accessibilityFeatureClass == accessibilityFeatureClass
        }
        guard !featuresToUpload.isEmpty else { return }
        if accessibilityFeatureClass.isWay {
            try uploadWay(accessibilityFeatures: featuresToUpload)
        } else {
            try uploadNodes(accessibilityFeatures: featuresToUpload)
        }
    }
    
    func uploadCaptureNode(
        accessibilityFeatureClass: AccessibilityFeatureClass,
        classAnnotationOption: AnnotationOption
    ) throws {
        
    }
    
    func uploadNodes(accessibilityFeatures: [AccessibilityFeature]) throws {
        var id: Int = 0
        let version: Int = 1
        let featureNodes: [OSMNode] = accessibilityFeatures.compactMap { feature in
            id -= 1
            return featureToNode(feature, id: String(id), version: String(version))
        }
    }
    
    func uploadWay(accessibilityFeatures: [AccessibilityFeature]) throws {
        guard let firstFeature = accessibilityFeatures.first else {
            return
        }
        var id: Int = 0
        let version: Int = 1
        let featureNodes: [OSMNode] = accessibilityFeatures.compactMap { feature in
            id -= 1
            return featureToNode(feature, id: String(id), version: String(version))
        }
        /// Only 1 node per way feature is supported currently
        guard featureNodes.count >= 1, let firstNode = featureNodes.first else {
            return
        }
        let featureWay = featureToWay(
            firstFeature.accessibilityFeatureClass,
            featureNodes: [firstNode],
            id: String(-1),
            version: String(version)
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
