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
    let ref: String
    let role: String
    
    var toXML: String {
        return "<member type=\"\(element.elementOSMString)\" ref=\"\(ref)\" role=\"\(role)\" />"
    }
}

struct OSWPolygon: OSWElement {
    let elementOSMString: String = "relation"
    
    let id: String
    let version: String
    let oswElementClass: OSWElementClass
    
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    
    var members: [any OSWElement]
    
    var tags: [String: String] {
        let identifyingFieldTags = oswElementClass.identifyingFieldTags
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
    
    func toOSMCreateXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let membersXML = members.map { $0.toOSMCreateXML(changesetId: changesetId) }.joined(separator: "\n")
        return """
        <relation id="\(id)" changeset="\(changesetId)">
            \(membersXML)
            \(tagsXML)
        </relation>
        """
    }
    
    /**
     - WARNING:
     Currently, this xml includes ALL the members for modification. This is not optimal as only the members that have changed should be included.
     */
    func toOSMModifyXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let membersXML = members.map { $0.toOSMCreateXML(changesetId: changesetId) }.joined(separator: "\n")
        return """
        <relation id="\(id)" version="\(version)" changeset="\(changesetId)">
            \(membersXML)
            \(tagsXML)
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
}
