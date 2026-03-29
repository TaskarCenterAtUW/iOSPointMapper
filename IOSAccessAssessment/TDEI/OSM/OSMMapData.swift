//
//  OSMMapDataResponse.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/28/26.
//

import Foundation

enum OSMMapDataError: Error, LocalizedError {
    case invalidNodeCoordinates
    
    var errorDescription: String? {
        switch self {
        case .invalidNodeCoordinates:
            return "Node has invalid coordinates."
        }
    }
}

struct OSMMapDataResponse: Codable {
    let version, generator, copyright: String
    let attribution, license: String
    let bounds: Bounds
    let elements: [OSMMapDataResponseElement]
    
    func getOSMElements() -> [String: any OSMElement] {
        var osmElements: [String: any OSMElement] = [:]
        for element in elements {
            if let osmElement = try? element.toOSMElement() {
                osmElements["\(element.id)"] = osmElement
            }
        }
        return osmElements
    }
}

struct Bounds: Codable { // use this for bounds in the map
    public let minlat, minlon, maxlat, maxlon: Double
}

struct OSMMapDataResponseElement: Codable {
    public var isInteresting: Bool? = false
    public var isSkippable: Bool? = false
    public let type: OSMElementType
    public let id: Int
    public let lat, lon: Double?
    public let timestamp: Date
    public var version, changeset: Int
    public let user: String
    public let uid: Int
    public let tags: [String: String]
    public let nodes: [Int]?
    public let members: [OSMRelationMember]?
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isInteresting = try values.decodeIfPresent(Bool.self, forKey: .isInteresting) ?? false
        isSkippable = try values.decodeIfPresent(Bool.self, forKey: .isSkippable) ?? false
        id = try values.decodeIfPresent(Int.self, forKey: .id) ?? 0
        lat = try values.decodeIfPresent(Double.self, forKey: .lat) ?? 0.0
        lon = try values.decodeIfPresent(Double.self, forKey: .lon) ?? 0.0
        timestamp = try values.decodeIfPresent(Date.self, forKey: .timestamp) ?? Date()
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        changeset = try values.decodeIfPresent(Int.self, forKey: .changeset) ?? 0
        user = try values.decodeIfPresent(String.self, forKey: .user) ?? ""
        uid = try values.decodeIfPresent(Int.self, forKey: .uid) ?? 0
        tags = try values.decodeIfPresent([String: String].self, forKey: .tags) ?? [:]
        nodes = try values.decodeIfPresent([Int].self, forKey: .nodes) ?? []
        type = try values.decodeIfPresent(OSMElementType.self, forKey: .type) ?? OSMElementType.node
        members = try values.decodeIfPresent([OSMRelationMember].self, forKey: .members) ?? []
    }
    
    func toOSMElement() throws -> (any OSMElement)? {
        switch type {
        case .node:
            return try toOSMNode()
        case .way:
            return toOSMWay()
        case .relation:
            return toOSMRelation()
        }
    }
//    
    private func toOSMNode() throws -> OSMNode {
        guard let lat = lat, let lon = lon else {
            throw OSMMapDataError.invalidNodeCoordinates
        }
        return OSMNode(id: "\(id)", version: "\(version)", latitude: lat, longitude: lon, tags: tags)
    }
    
    private func toOSMWay() -> OSMWay {
        let nodeRefs = nodes?.map { "\($0)" } ?? []
        return OSMWay(id: "\(id)", version: "\(version)", tags: tags, nodeRefs: nodeRefs)
    }
    
    private func toOSMRelation() -> OSMRelation {
        return OSMRelation(id: "\(id)", version: "\(version)", tags: tags, members: members ?? [])
    }
}
