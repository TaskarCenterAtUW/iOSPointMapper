//
//  OSWNode.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/9/25.
//

import Foundation
import CoreLocation

struct OSWPoint: OSWElement {
    let elementOSMString: String = "node"
    
    let id: String
    let version: String
    let oswElementClass: OSWElementClass
    
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    
    var tags: [String: String] {
        var identifyingFieldTags: [String: String] = [:]
        if oswElementClass.geometry == .point {
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
        let tagElements = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        return """
        <node id="\(id)" lat="\(latitude)" lon="\(longitude)" changeset="\(changesetId)">
            \(tagElements)
        </node>
        """
    }
    
    func toOSMModifyXML(changesetId: String) -> String {
        let tagElements = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        return """
        <node id="\(id)" changeset="\(changesetId)" version="\(version)" lat="\(latitude)" lon="\(longitude)">
            \(tagElements)
        </node>
        """
    }
    
    func toOSMDeleteXML(changesetId: String) -> String {
        return """
        <node id="\(id)" version="\(version)" changeset="\(changesetId)" lat="\(latitude)" lon="\(longitude)"/>
        """
    }
    
    var description: String {
        return "OSWPoint(id: \(id), version: \(version), latitude: \(latitude), longitude: \(longitude))"
    }
    
    var shortDescription: String {
        return "OSWPoint(id: \(id))"
    }
}
