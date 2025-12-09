//
//  OSWLineString.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/9/25.
//

import Foundation
import CoreLocation

struct OSWLineString: OSWElement {
    let elementOSMString: String = "way"
    
    let id: String
    let version: String
    let oswElementClass: OSWElementClass
    
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    
    var nodes: [OSWPoint]
    
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
        let refsXML = nodes.map { "<nd ref=\"\($0.id)\" />" }.joined(separator: "\n")
        let nodesXML = nodes.map { $0.toOSMCreateXML(changesetId: changesetId) }.joined(separator: "\n")
        let wayXML = """
        <way id="\(id)" changeset="\(changesetId)">
            \(tagsXML)
            \(refsXML)
        </way>
        """
        return nodesXML + "\n" + wayXML
    }
    
    /**
     - WARNING:
     Currently, this xml includes ALL the nodes for modification. This is not optimal as only the nodes that have changed should be included.
     */
    func toOSMModifyXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let refsXML = nodes.map { "<nd ref=\"\($0.id)\" />" }.joined(separator: "\n")
        let nodesXML = nodes.map { $0.toOSMModifyXML(changesetId: changesetId) }.joined(separator: "\n")
        let wayXML = """
        <way id="\(id)" version="\(version)" changeset="\(changesetId)">
            \(tagsXML)
            \(refsXML)
        </way>
        """
        return nodesXML + "\n" + wayXML
    }
    
    /**
     - WARNING:
     The delete strategy of way elements has not been properly considered yet.
     */
    func toOSMDeleteXML(changesetId: String) -> String {
        return """
        <way id="\(id)" version="\(version)" changeset="\(changesetId)"/>
        """
    }
}
