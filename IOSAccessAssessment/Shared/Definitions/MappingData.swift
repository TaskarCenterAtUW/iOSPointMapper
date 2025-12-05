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

struct MappingWayData: Sendable {
    let way: OSMWay
    var nodes: [MappedAccessibilityFeature]
    
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
    
    var featureWayMap: [AccessibilityFeatureClass: [MappingWayData]] = [:]
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
    
    func appendWay(
        featureClass: AccessibilityFeatureClass, osmWay: OSMWay, nodes: [MappedAccessibilityFeature]
    ) throws {
        guard featureClass.isWay else {
            throw MappingDataError.featureClassNotWay(featureClass)
        }
        let wayDataIndex = findWayDataIndex(featureClass: featureClass, osmWay: osmWay)
        if var existingWayDataList = featureWayMap[featureClass],
           let wayDataIndex = wayDataIndex,
           wayDataIndex < existingWayDataList.count {
            var existingWayData = existingWayDataList[wayDataIndex]
            existingWayData.appendNodes(contentsOf: nodes)
            existingWayDataList[wayDataIndex] = existingWayData
            featureWayMap[featureClass] = existingWayDataList
        } else {
            let wayData = MappingWayData(way: osmWay, nodes: nodes)
            featureWayMap[featureClass, default: []].append(wayData)
        }
    }
    
    func appendNodesToWay(
        featureClass: AccessibilityFeatureClass, wayData: MappingWayData, nodes: [MappedAccessibilityFeature]
    ) throws {
        let osmWay = wayData.way
        try appendWay(featureClass: featureClass, osmWay: osmWay, nodes: nodes)
    }
    
    func appendWayDataToWay(
        featureClass: AccessibilityFeatureClass, wayData: MappingWayData, wayDataToAppend: MappingWayData
    ) throws {
        let osmWay = wayData.way
        let nodesToAppend = wayDataToAppend.nodes
        try appendWay(featureClass: featureClass, osmWay: osmWay, nodes: nodesToAppend)
    }
    
    private func findWayDataIndex(
        featureClass: AccessibilityFeatureClass, osmWay: OSMWay
    ) -> Int? {
        guard let wayDataList = featureWayMap[featureClass] else {
            return nil
        }
        return wayDataList.firstIndex(where: { $0.way.id == osmWay.id })
    }
}
