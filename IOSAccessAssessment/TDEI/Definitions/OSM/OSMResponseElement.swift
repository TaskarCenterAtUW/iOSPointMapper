//
//  OSMResponseElement.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/2/25.
//

import Foundation

protocol OSMResponseElement: Sendable, Equatable, Hashable {
    var oldId: String { get }
    var newId: String { get }
    var newVersion: String { get }
}

struct OSMResponseNode: OSMResponseElement {
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

struct OSMResponseWay: OSMResponseElement {
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

