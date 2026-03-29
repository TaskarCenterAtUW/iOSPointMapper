//
//  OSMMapDataResponse.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/28/26.
//

import Foundation

struct OSMMapDataResponse: Codable {
    public let version, generator, copyright: String
    public let attribution, license: String
    public let bounds: Bounds
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
        type = try values.decodeIfPresent(OSMElementType.self, forKey: .type) ?? TypeEnum.node
        members = try values.decodeIfPresent([OSMRelationMember].self, forKey: .members) ?? []
    }
    
//    func toOSMElement() -> OSMElement? {
//        switch type {
//        case .node:
//            return toOSMNode()
//        case .way:
//            return toOSMWay()
//        case .relation:
//            return nil
//        }
//    }
//    
//    private func toOSMNode() -> OSMNode {
//        OSMNode(type: "node", id: id, lat: lat!, lon: lon!, timestamp: timestamp, version: version, changeset: changeset, user: user, uid: uid,tags: tags)
//    }
//    private func toOSMWay() -> OSMWay {
//        OSMWay(type: "way", id: id, timestamp: timestamp, version: version, changeset: changeset, user: user, uid: uid, nodes: nodes ?? [], tags: tags)
//    }
}
