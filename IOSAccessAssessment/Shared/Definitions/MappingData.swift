//
//  MapData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation

enum MappingDataError: Error, LocalizedError {
    case accessibilityFeatureClassNotWay(AccessibilityFeatureClass)
    case noActiveWayForFeatureClass(AccessibilityFeatureClass)
    case accessibilityFeatureNodeNotPresent(AccessibilityFeatureClass)
    
    var errorDescription: String? {
        switch self {
        case .accessibilityFeatureClassNotWay(let accessibilityFeatureClass):
            return "Feature class is not a way: \(accessibilityFeatureClass.name)"
        case .noActiveWayForFeatureClass(let accessibilityFeatureClass):
            return "No active way found for feature class: \(accessibilityFeatureClass.name)"
        case .accessibilityFeatureNodeNotPresent(let accessibilityFeatureClass):
            return "No accessibility feature node present for feature class: \(accessibilityFeatureClass.name)"
        }
    }
}

class MappingData: CustomStringConvertible {
    var featuresMap: [AccessibilityFeatureClass: [MappedAccessibilityFeature]] = [:]
    var featureIdToIndexDictMap: [AccessibilityFeatureClass: [UUID: Int]] = [:]
    
    /// Ways that are currently being processed/constructed. Only one active feature per feature class at a time.
    var activeFeatureIdMap: [AccessibilityFeatureClass: UUID] = [:]
    
    init() { }
    
    func getActiveFeature(accessibilityFeatureClass: AccessibilityFeatureClass) -> MappedAccessibilityFeature? {
        let activeFeatureId = activeFeatureIdMap[accessibilityFeatureClass]
        guard let activeFeatureId else { return nil }
        guard let featureIdToIndexDict = featureIdToIndexDictMap[accessibilityFeatureClass],
              let featureIndex = featureIdToIndexDict[activeFeatureId],
              let features = featuresMap[accessibilityFeatureClass], featureIndex < features.count else {
            return nil
        }
        return features[featureIndex]
    }
    
    /**
     Updates features in the mapping data for a specific feature class.
     */
    func updateFeatures(_ features: [MappedAccessibilityFeature], for featureClass: AccessibilityFeatureClass) {
        var existingFeatures = featuresMap[featureClass, default: []]
        var featureIdToIndexDict = featureIdToIndexDictMap[featureClass, default: [:]]
        features.forEach { feature in
            if let index = featureIdToIndexDict[feature.id] {
                // Update existing feature
                existingFeatures[index] = feature
            } else {
                // Append new feature
                existingFeatures.append(feature)
                featureIdToIndexDict[feature.id] = existingFeatures.count - 1
            }
            activeFeatureIdMap[featureClass] = feature.id
        }
        featuresMap[featureClass] = existingFeatures
        featureIdToIndexDictMap[featureClass] = featureIdToIndexDict
    }
    
    var description: String {
        var desc = "MappingData:\n"
        desc += "Feature Nodes:\n"
        featuresMap.forEach { (featureClass, featureData) in
            return featureData.forEach { feature in
                desc += feature.oswElement.description + "\n"
            }
        }
        return desc
    }
}
