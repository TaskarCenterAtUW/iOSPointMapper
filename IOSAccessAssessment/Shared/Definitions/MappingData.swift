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
    var featureMap: [AccessibilityFeatureClass: [MappedAccessibilityFeature]] = [:]
    
    /// Ways that are currently being processed/constructed. Only one active way per feature class at a time.
    var activeFeatureWays: [AccessibilityFeatureClass: MappedAccessibilityFeature] = [:]
    
    /// Relations that are currently being processed/constructed. Only one active relation per feature class at a time.
    var activeFeatureRelations: [AccessibilityFeatureClass: MappedAccessibilityFeature] = [:]
    
    init() { }
    
    func getActiveFeatureWayData(accessibilityFeatureClass: AccessibilityFeatureClass) -> MappedAccessibilityFeature? {
        return activeFeatureWays[accessibilityFeatureClass]
    }
    
    func appendFeatures(_ features: [MappedAccessibilityFeature], for featureClass: AccessibilityFeatureClass) {
        let existingFeatures = featureMap[featureClass, default: []]
        featureMap[featureClass] = existingFeatures + features
    }
    
    var description: String {
        var desc = "MappingData:\n"
        desc += "Feature Nodes:\n"
        featureMap.forEach { (featureClass, featureData) in
            return featureData.forEach { feature in
                desc += feature.oswElement.description + "\n"
            }
        }
        return desc
    }
}
