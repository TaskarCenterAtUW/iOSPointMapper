//
//  OSMElement.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/17/25.
//

protocol OSMElement: Sendable, Equatable {
    var id: String { get }
    var version: String { get }
    
    func toOSMCreateXML(changesetId: String) -> String
    func toOSMModifyXML(changesetId: String) -> String
    func toOSMDeleteXML(changesetId: String) -> String
}

enum OSMEntityType: String, Sendable, Codable, Equatable, Hashable, CaseIterable {
    case node
    case edge
    case zone
    
    var description: String {
        switch self {
        case .node:
            return "Node"
        case .edge:
            return "Edge"
        case .zone:
            return "Zone"
        }
    }
}
