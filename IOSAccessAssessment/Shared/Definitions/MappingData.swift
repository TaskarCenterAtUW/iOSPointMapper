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

final class MappingNodeData {
    var nodes: [MappedAccessibilityFeature] = []
    
    init(nodes: [MappedAccessibilityFeature] = []) {
        self.nodes = nodes
    }
    
    func append(_ featureNode: MappedAccessibilityFeature) {
        nodes.append(featureNode)
    }
    
    func append(contentsOf featureNodes: [MappedAccessibilityFeature]) {
        nodes.append(contentsOf: featureNodes)
    }
}

final class MappingWayData {
    var way: OSMWay
    var nodes: [MappedAccessibilityFeature]
    
    init(way: OSMWay, nodes: [MappedAccessibilityFeature] = []) {
        self.way = way
        self.nodes = nodes
    }
    
    func appendNode(_ featureNode: MappedAccessibilityFeature) {
        let nodeId = featureNode.osmNode.id
        self.way.nodeRefs.append(nodeId)
        self.nodes.append(featureNode)
    }
    
    func appendNodes(contentsOf featureNodes: [MappedAccessibilityFeature]) {
        let nodeIds = featureNodes.map { $0.osmNode.id }
        self.way.nodeRefs.append(contentsOf: nodeIds)
        nodes.append(contentsOf: featureNodes)
    }
    
    func appendWayData(_ wayData: MappingWayData) {
        appendNodes(contentsOf: wayData.nodes)
    }
    
    func update(way: OSMWay, nodes: [MappedAccessibilityFeature]) {
        self.way = way
        self.appendNodes(contentsOf: nodes)
    }
}

class MappingData: CustomStringConvertible {
    var featureNodeMap: [AccessibilityFeatureClass: MappingNodeData] = [:]
    
    var featureWayMap: [AccessibilityFeatureClass: [MappingWayData]] = [:]
    /// Ways that are currently being processed/constructed. Only one active way per feature class at a time.
    var activeFeatureWays: [AccessibilityFeatureClass: MappingWayData] = [:]
    
    init() { }
    
    func appendNode(accessibilityFeatureClass: AccessibilityFeatureClass, node: MappedAccessibilityFeature) {
        let existingNodeData = featureNodeMap[accessibilityFeatureClass, default: MappingNodeData()]
        existingNodeData.append(node)
        featureNodeMap[accessibilityFeatureClass] = existingNodeData
    }
    
    func appendNodes(accessibilityFeatureClass: AccessibilityFeatureClass, nodes: [MappedAccessibilityFeature]) {
        let existingNodeData = featureNodeMap[accessibilityFeatureClass, default: MappingNodeData()]
        existingNodeData.append(contentsOf: nodes)
        featureNodeMap[accessibilityFeatureClass] = existingNodeData
    }
    
    func appendNodeData(accessibilityFeatureClass: AccessibilityFeatureClass, nodeData: MappingNodeData) {
        appendNodes(accessibilityFeatureClass: accessibilityFeatureClass, nodes: nodeData.nodes)
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
        if let existingWayDataList = featureWayMap[accessibilityFeatureClass],
           let wayDataIndex = wayDataIndex,
           wayDataIndex < existingWayDataList.count {
            // Update existing way data
            existingWayDataList[wayDataIndex].update(way: osmWay, nodes: nodes)
            activeFeatureWays[accessibilityFeatureClass] = existingWayDataList[wayDataIndex]
        } else {
            let wayData = MappingWayData(way: osmWay, nodes: nodes)
            featureWayMap[accessibilityFeatureClass, default: []].append(wayData)
            activeFeatureWays[accessibilityFeatureClass] = wayData
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
    
    var description: String {
        var desc = "MappingData:\n"
        desc += "Feature Nodes:\n"
        featureNodeMap.forEach { (featureClass, nodeData) in
            desc += "- \(featureClass.name): \(nodeData.nodes.count) nodes\n"
            desc += "  Nodes IDs: \(nodeData.nodes.map { $0.osmNode.id })\n"
        }
        desc += "Feature Ways:\n"
        featureWayMap.forEach { (featureClass, wayDataList) in
            desc += "- \(featureClass.name): \(wayDataList.count) ways\n"
            for (index, wayData) in wayDataList.enumerated() {
                desc += "  Way \(index + 1) ID: \(wayData.way.id), Nodes IDs: \(wayData.nodes.map { $0.osmNode.id })\n"
            }
        }
        return desc
    }
}
