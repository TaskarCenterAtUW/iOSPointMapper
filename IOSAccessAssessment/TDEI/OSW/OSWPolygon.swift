//
//  OSWPolygon.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/9/25.
//

import Foundation
import CoreLocation

struct OSWRelationMember: Sendable {
    let element: any OSWElement
    let role: String
    
    init(element: any OSWElement, role: String) {
        self.element = element
        self.role = role
    }
    
    init(element: any OSWElement) {
        self.element = element
        self.role = "outer"
    }
    
    var toXML: String {
        return "<member type=\"\(element.elementOSMString)\" ref=\"\(element.id)\" role=\"\(role)\" />"
    }
}

struct OSWPolygon: OSWElement {
    let elementOSMString: String = "relation"
    
    let id: String
    let version: String
    let oswElementClass: OSWElementClass
    
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    
    /// TODO: Add the proper support for member (specifically roles).
    var members: [OSWRelationMember]
    
    var tags: [String: String] {
        var identifyingFieldTags: [String: String] = [:]
        if oswElementClass.geometry == .polygon {
            identifyingFieldTags = oswElementClass.identifyingFieldTags
        }
        var attributeTags: [String: String] = [:]
        attributeValues.forEach { attributeKeyValuePair in
            let attributeKey = attributeKeyValuePair.key
            let attributeTagKey = attributeKey.osmTagKey
            let attributeValue = attributeKeyValuePair.value
            let attributeTagValue = attributeKey.getOSMTagFromValue(attributeValue: attributeValue)
            guard let attributeTagValue else { return }
            attributeTags[attributeTagKey] = attributeTagValue
        }
        let tags = identifyingFieldTags.merging(attributeTags) { _, new in
            return new
        }
        return tags
    }
    
    /**
     - TODO:
     Depending on the type of polygon, add the polygon type tag (e.g. "type"="multipolygon") if required.
     */
    func toOSMCreateXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let membersXML = members.map {
            $0.element.toOSMCreateXML(changesetId: changesetId)
        }.joined(separator: "\n")
        let memberRefsXML = members.map { $0.toXML }.joined(separator: "\n")
        return """
        \(membersXML)
        <relation id="\(id)" changeset="\(changesetId)">
            \(tagsXML)
            \(memberRefsXML)
        </relation>
        """
    }
    
    /**
     - WARNING:
     Currently, this xml includes ALL the members for modification. This is not optimal as only the members that have changed should be included.
     
     - TODO:
     Depending on the type of polygon, add the polygon type tag (e.g. "type"="multipolygon") if required.
     */
    func toOSMModifyXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let membersXML = members.map {
            $0.element.toOSMModifyXML(changesetId: changesetId)
        }.joined(separator: "\n")
        let memberRefsXML = members.map { $0.toXML }.joined(separator: "\n")
        return """
        \(membersXML)
        <relation id="\(id)" version="\(version)" changeset="\(changesetId)">
            \(tagsXML)
            \(memberRefsXML)
        </relation>
        """
    }
    
    /**
     - WARNING:
     The delete strategy of way elements has not been properly considered yet.
     */
    func toOSMDeleteXML(changesetId: String) -> String {
        return """
        <relation id="\(id)" version="\(version)" changeset="\(changesetId)"/>
        """
    }
    
    var description: String {
        let membersString = members.map {
            $0.element.shortDescription
        }.joined(separator: ", ")
        return "OSWPolygon(id: \(id), version: \(version), class: \(oswElementClass), members: [\(membersString)])"
    }
    
    var shortDescription: String {
        return "OSWPolygon(id: \(id))"
    }
}
