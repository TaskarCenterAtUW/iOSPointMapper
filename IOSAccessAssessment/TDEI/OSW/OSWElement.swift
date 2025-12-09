//
//  OSWIdentifyingField.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//

enum OSWElement: String, CaseIterable, Hashable, Sendable {
    case BareNode
    
    struct Metadata: Sendable {
        let description: String
        let parent: OSWElement?
        let geometry: OSWGeometry
        let identifyingFields: [String: String] = [:]
    }
    
    var metadata: Metadata {
        switch self {
        case .BareNode:
            return Metadata(
                description: "A special case of an abstract Node.",
                parent: nil,
                geometry: .point
            )
        }
    }
}

/**
 Additional properties for OSWElement
 */
extension OSWElement {
    var description: String {
        return metadata.description
    }
    
    var parent: OSWElement? {
        return metadata.parent
    }
}
