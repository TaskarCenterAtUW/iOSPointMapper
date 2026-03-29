//
//  OSMChangesetUploadResponseElement.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/2/25.
//

import Foundation

protocol OSMChangesetUploadResponseElement: Sendable, Equatable, Hashable {
    var oldId: String { get }
    var newId: String { get }
    var newVersion: String { get }
}

struct OSMChangesetUploadResponseNode: OSMChangesetUploadResponseElement {
    let oldId: String
    let newId: String
    let newVersion: String
    
    let attributeDict: [String: String]
    
    init(oldId: String, newId: String, newVersion: String, attributeDict: [String: String] = [:]) {
        self.oldId = oldId
        self.newId = newId
        self.newVersion = newVersion
        self.attributeDict = attributeDict
    }
}

struct OSMChangesetUploadResponseWay: OSMChangesetUploadResponseElement {
    let oldId: String
    let newId: String
    let newVersion: String
    
    let attributeDict: [String: String]
    
    init(oldId: String, newId: String, newVersion: String, attributeDict: [String: String] = [:]) {
        self.oldId = oldId
        self.newId = newId
        self.newVersion = newVersion
        self.attributeDict = attributeDict
    }
}

struct OSMChangesetUploadResponseRelation: OSMChangesetUploadResponseElement {
    let oldId: String
    let newId: String
    let newVersion: String
    
    let attributeDict: [String: String]
    
    init(oldId: String, newId: String, newVersion: String, attributeDict: [String: String] = [:]) {
        self.oldId = oldId
        self.newId = newId
        self.newVersion = newVersion
        self.attributeDict = attributeDict
    }
}

struct OSMChangesetUploadResponseElements: Sendable {
    let nodes: [String: OSMChangesetUploadResponseNode]
    let ways: [String: OSMChangesetUploadResponseWay]
    let relations: [String: OSMChangesetUploadResponseRelation]
    
    var oldToNewIdMap: [String: String] {
        let nodeMap = nodes.reduce(into: [String: String]()) { dict, pair in
            dict[pair.value.oldId] = pair.value.newId
        }
        let wayMap = ways.reduce(into: [String: String]()) { dict, pair in
            dict[pair.value.oldId] = pair.value.newId
        }
        let relationMap = relations.reduce(into: [String: String]()) { dict, pair in
            dict[pair.value.oldId] = pair.value.newId
        }
        return nodeMap.merging(wayMap) { _, new in new }
            .merging(relationMap) { _, new in new }
    }
}
