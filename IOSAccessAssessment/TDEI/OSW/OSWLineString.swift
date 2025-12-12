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
    
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    
    var points: [OSWPoint]
    
    init(
        id: String, version: String,
        oswElementClass: OSWElementClass,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        points: [OSWPoint]
    ) {
        self.id = id
        self.version = version
        self.oswElementClass = oswElementClass
        self.attributeValues = attributeValues
        self.points = points
    }
    
    var tags: [String: String] {
        var identifyingFieldTags: [String: String] = [:]
        if oswElementClass.geometry == .linestring {
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
    
    func toOSMCreateXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let refsXML = points.map { "<nd ref=\"\($0.id)\" />" }.joined(separator: "\n")
        let nodesXML = points.map { $0.toOSMCreateXML(changesetId: changesetId) }.joined(separator: "\n")
        return """
        \(nodesXML)
        <way id="\(id)" changeset="\(changesetId)">
            \(tagsXML)
            \(refsXML)
        </way>
        """
    }
    
    /**
     - WARNING:
     Currently, this xml includes ALL the nodes for modification. This is not optimal as only the nodes that have changed should be included.
     */
    func toOSMModifyXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let refsXML = points.map { "<nd ref=\"\($0.id)\" />" }.joined(separator: "\n")
        let nodesXML = points.map { $0.toOSMModifyXML(changesetId: changesetId) }.joined(separator: "\n")
        return """
        \(nodesXML)
        <way id="\(id)" version="\(version)" changeset="\(changesetId)">
            \(tagsXML)
            \(refsXML)
        </way>
        """
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
    
    var description: String {
        let nodesString = points.map { $0.shortDescription }.joined(separator: ", ")
        return "OSWLineString(id: \(id), version: \(version), nodes: [\(nodesString)])"
    }
    
    var shortDescription: String {
        return "OSWLineString(id: \(id))"
    }
}
