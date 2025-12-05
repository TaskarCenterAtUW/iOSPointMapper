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

struct MappingNodeData: Sendable {
    var nodes: [MappedAccessibilityFeature] = []
    
    mutating func append(_ featureNode: MappedAccessibilityFeature) {
        nodes.append(featureNode)
    }
    
    mutating func append(contentsOf featureNodes: [MappedAccessibilityFeature]) {
        nodes.append(contentsOf: featureNodes)
    }
}

struct MappingWayData: Sendable, Hashable {
    let way: OSMWay
    var nodes: [MappedAccessibilityFeature] = []
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(way)
    }
    
    mutating func appendNode(_ featureNode: MappedAccessibilityFeature) {
        nodes.append(featureNode)
    }
    
    mutating func appendNodes(contentsOf featureNodes: [MappedAccessibilityFeature]) {
        nodes.append(contentsOf: featureNodes)
    }
    
    mutating func appendWayData(_ wayData: MappingWayData) {
        nodes.append(contentsOf: wayData.nodes)
    }
}

class MappingData {
    var featureNodeMap: [AccessibilityFeatureClass: MappingNodeData] = [:]
    
    var featureWayMap: [AccessibilityFeatureClass: Set<MappingWayData>] = [:]
    /// Ways that are currently being processed/constructed. Only one active way per feature class at a time.
    var activeFeatureWays: [AccessibilityFeatureClass: MappingWayData] = [:]
    
    init() { }
    
    func appendNode(featureClass: AccessibilityFeatureClass, node: MappedAccessibilityFeature) {
        featureNodeMap[featureClass, default: MappingNodeData()].append(node)
    }
    
    func appendNodes(featureClass: AccessibilityFeatureClass, nodes: [MappedAccessibilityFeature]) {
        featureNodeMap[featureClass, default: MappingNodeData()].append(contentsOf: nodes)
    }
    
    func appendNodeData(featureClass: AccessibilityFeatureClass, nodeData: MappingNodeData) {
        featureNodeMap[featureClass, default: MappingNodeData()].append(contentsOf: nodeData.nodes)
    }
    
    func getActiveFeatureWayData(featureClass: AccessibilityFeatureClass) -> MappingWayData? {
        return activeFeatureWays[featureClass]
    }
    
    func appendWayData(
        featureClass: AccessibilityFeatureClass, wayData: MappingWayData, nodes: [MappedAccessibilityFeature]
    ) throws {
        guard featureClass.isWay else {
            throw MappingDataError.featureClassNotWay(featureClass)
        }
        var wayData = wayData
        wayData.appendNodes(contentsOf: nodes)
        activeWays[featureClass] = wayData
        
        featureWayMap[featureClass, default: []].insert(wayData)
    }
    
    func appendNodesToWay(
        featureClass: AccessibilityFeatureClass, wayData: MappingWayData, nodes: [MappedAccessibilityFeature]
    ) throws {
        guard featureClass.isWay else {
            throw MappingDataError.featureClassNotWay(featureClass)
        }
        var wayData = wayData
        wayData.appendNodes(contentsOf: nodes)
        activeWays[featureClass] = wayData
        
        featureWayMap[featureClass, default: []].update(with: wayData)
    }
    
    func appendWayDataToWay(
        featureClass: AccessibilityFeatureClass, wayData: MappingWayData, wayDataToAppend: MappingWayData
    ) throws {
        guard featureClass.isWay else {
            throw MappingDataError.featureClassNotWay(featureClass)
        }
        if featureWayMap[featureClass] == nil {
            featureWayMap[featureClass] = []
        }
        var wayData = wayData
        wayData.appendWayData(wayDataToAppend)
        activeWays[featureClass] = wayData
        
        featureWayMap[featureClass, default: []].update(with: wayData)
    }
}
