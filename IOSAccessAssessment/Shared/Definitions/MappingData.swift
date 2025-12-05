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
    
    var errorDescription: String? {
        switch self {
        case .accessibilityFeatureClassNotWay(let accessibilityFeatureClass):
            return "Feature class is not a way: \(accessibilityFeatureClass.name)"
        case .noActiveWayForFeatureClass(let accessibilityFeatureClass):
            return "No active way found for feature class: \(accessibilityFeatureClass.name)"
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
    
    func appendNode(accessibilityFeatureClass: AccessibilityFeatureClass, node: MappedAccessibilityFeature) {
        featureNodeMap[accessibilityFeatureClass, default: MappingNodeData()].append(node)
    }
    
    func appendNodes(accessibilityFeatureClass: AccessibilityFeatureClass, nodes: [MappedAccessibilityFeature]) {
        featureNodeMap[accessibilityFeatureClass, default: MappingNodeData()].append(contentsOf: nodes)
    }
    
    func appendNodeData(accessibilityFeatureClass: AccessibilityFeatureClass, nodeData: MappingNodeData) {
        featureNodeMap[accessibilityFeatureClass, default: MappingNodeData()].append(contentsOf: nodeData.nodes)
    }
    
    func getActiveFeatureWayData(accessibilityFeatureClass: AccessibilityFeatureClass) -> MappingWayData? {
        return activeFeatureWays[accessibilityFeatureClass]
    }
    
    func appendWay(
        accessibilityFeatureClass: AccessibilityFeatureClass, osmWay: OSMWay, nodes: [MappedAccessibilityFeature]
    ) throws {
        guard accessibilityFeatureClass.isWay else {
            throw MappingDataError.accessibilityFeatureClassNotWay(accessibilityFeatureClass)
        }
        let wayDataIndex = findWayDataIndex(accessibilityFeatureClass: accessibilityFeatureClass, osmWay: osmWay)
        if var existingWayDataList = featureWayMap[accessibilityFeatureClass],
           let wayDataIndex = wayDataIndex,
           wayDataIndex < existingWayDataList.count {
            var existingWayData = existingWayDataList[wayDataIndex]
            existingWayData.appendNodes(contentsOf: nodes)
            existingWayDataList[wayDataIndex] = existingWayData
            featureWayMap[accessibilityFeatureClass] = existingWayDataList
        } else {
            let wayData = MappingWayData(way: osmWay, nodes: nodes)
            featureWayMap[accessibilityFeatureClass, default: []].append(wayData)
        }
    }
    
    func appendNodesToWay(
        accessibilityFeatureClass: AccessibilityFeatureClass, wayData: MappingWayData, nodes: [MappedAccessibilityFeature]
    ) throws {
        let osmWay = wayData.way
        try appendWay(accessibilityFeatureClass: accessibilityFeatureClass, osmWay: osmWay, nodes: nodes)
    }
    
    func appendWayDataToWay(
        accessibilityFeatureClass: AccessibilityFeatureClass, wayData: MappingWayData, wayDataToAppend: MappingWayData
    ) throws {
        let osmWay = wayData.way
        let nodesToAppend = wayDataToAppend.nodes
        try appendWay(accessibilityFeatureClass: accessibilityFeatureClass, osmWay: osmWay, nodes: nodesToAppend)
    }
    
    private func findWayDataIndex(
        accessibilityFeatureClass: AccessibilityFeatureClass, osmWay: OSMWay
    ) -> Int? {
        guard let wayDataList = featureWayMap[accessibilityFeatureClass] else {
            return nil
        }
        return wayDataList.firstIndex(where: { $0.way.id == osmWay.id })
    }
}
