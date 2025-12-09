//
//  OSMRelation.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/9/25.
//

import Foundation

enum OSMRelationMemberType: String, Sendable {
    case node
    case way
    case relation
    
    var description: String {
        return self.rawValue
    }
}

struct OSMRelationMember: Sendable, Equatable, Hashable {
    let type: OSMRelationMemberType
    let ref: String
    let role: String
    
    var toXML: String {
        return "<member type=\"\(type.rawValue)\" ref=\"\(ref)\" role=\"\(role)\" />"
    }
}

struct OSMRelation: OSMElement {
    let id: String
    let version: String
    let tags: [String: String]
    let members: [OSMRelationMember]
    
    init(id: String = "-3", version: String = "1", tags: [String: String], members: [OSMRelationMember]) {
        self.id = id
        self.version = version
        self.tags = tags
        self.members = members
    }
    
    func toOSMCreateXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let membersXML = members.map { $0.toXML }.joined(separator: "\n")
        return """
        <relation id="\(id)" changeset="\(changesetId)">
            \(membersXML)
            \(tagsXML)
        </relation>
        """
    }
    
    func toOSMModifyXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let membersXML = members.map { $0.toXML }.joined(separator: "\n")
        return """
        <relation id="\(id)" version="\(version)" changeset="\(changesetId)">
            \(membersXML)
            \(tagsXML)
        </relation>
        """
    }
    
    func toOSMDeleteXML(changesetId: String) -> String {
        return """
        <relation id="\(id)" version="\(version)" changeset="\(changesetId)"/>
        """
    }
}
