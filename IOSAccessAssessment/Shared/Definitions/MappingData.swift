//
//  MapData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation

enum MappingDataError: Error, LocalizedError {
    case featureClassNotWay(AccessibilityFeatureClass)
    case noActiveWayForFeatureClass(AccessibilityFeatureClass)
    
    var errorDescription: String? {
        switch self {
        case .featureClassNotWay(let featureClass):
            return "Feature class is not a way: \(featureClass.name)"
        case .noActiveWayForFeatureClass(let featureClass):
            return "No active way found for feature class: \(featureClass.name)"
        }
    }
}
    

class MappingData {
    var featureNodeMap: [AccessibilityFeatureClass: [MappedAccessibilityFeature]] = [:]
    
    var featureWayMap: [AccessibilityFeatureClass: [OSMWay: [MappedAccessibilityFeature]]] = [:]
    /// Ways that are currently being processed/constructed. Only one active way per feature class at a time.
    var activeWays: [AccessibilityFeatureClass: OSMWay] = [:]
    
    init() { }
    
    func appendFeatureNode(featureClass: AccessibilityFeatureClass, featureNode: MappedAccessibilityFeature) {
        if featureNodeMap[featureClass] == nil {
            featureNodeMap[featureClass] = []
        }
        featureNodeMap[featureClass]?.append(featureNode)
    }
    
    func appendFeatureNodes(featureClass: AccessibilityFeatureClass, featureNodes: [MappedAccessibilityFeature]) {
        if featureNodeMap[featureClass] == nil {
            featureNodeMap[featureClass] = []
        }
        featureNodeMap[featureClass]?.append(contentsOf: featureNodes)
    }
    
    func getActiveWay(featureClass: AccessibilityFeatureClass) -> OSMWay? {
        return activeWays[featureClass]
    }
    
    func appendWay(featureClass: AccessibilityFeatureClass, way: OSMWay, featureNodes: [MappedAccessibilityFeature]) throws {
        guard featureClass.isWay else {
            throw MappingDataError.featureClassNotWay(featureClass)
        }
        if featureWayMap[featureClass] == nil {
            featureWayMap[featureClass] = [:]
        }
        featureWayMap[featureClass]?[way] = featureNodes
        activeWays[featureClass] = way
    }
    
    func appendNodesToWay(
        featureClass: AccessibilityFeatureClass, way: OSMWay, featureNodes: [MappedAccessibilityFeature]
    ) throws {
        guard featureClass.isWay else {
            throw MappingDataError.featureClassNotWay(featureClass)
        }
        if featureWayMap[featureClass] == nil {
            featureWayMap[featureClass] = [:]
        }
        if featureWayMap[featureClass]?[way] == nil {
            featureWayMap[featureClass]?[way] = []
        }
        featureWayMap[featureClass]?[way]?.append(contentsOf: featureNodes)
    }
}
