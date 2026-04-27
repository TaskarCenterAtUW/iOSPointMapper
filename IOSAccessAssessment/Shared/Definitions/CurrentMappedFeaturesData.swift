//
//  CurrentMappedFeaturesData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation

enum CurrentMappedFeaturesDataError: Error, LocalizedError {
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

class CurrentMappedFeaturesData: CustomStringConvertible {
    var featuresMap: [AccessibilityFeatureClass: [MappedAccessibilityFeature]] = [:]
    var featureIdToIndexDictMap: [AccessibilityFeatureClass: [UUID: Int]] = [:]
    
    init() { }
    
    /**
     Updates features in the mapping data for a specific feature class by adding new features or updating existing ones based on their IDs.
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
        }
        featuresMap[featureClass] = existingFeatures
        featureIdToIndexDictMap[featureClass] = featureIdToIndexDict
    }
    
    var description: String {
        var desc = "CurrentMappedFeaturesData:\n"
        desc += "Feature Nodes:\n"
        featuresMap.forEach { (featureClass, featureData) in
            return featureData.forEach { feature in
                desc += feature.oswElement.description + "\n"
            }
        }
        return desc
    }
}
