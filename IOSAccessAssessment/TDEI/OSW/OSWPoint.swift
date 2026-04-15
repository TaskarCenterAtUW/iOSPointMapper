//
//  OSWNode.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/9/25.
//

import Foundation
import CoreLocation

struct OSWPoint: OSWElement {
    let osmElementType: OSMElementType = .node
    
    let id: String
    let version: String
    let oswElementClass: OSWElementClass
    
    var latitude: CLLocationDegrees
    var longitude: CLLocationDegrees
    
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]? = [:]
    var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    var additionalTags: [String : String] = [:]
    
    init(
        id: String, version: String,
        oswElementClass: OSWElementClass,
        latitude: CLLocationDegrees, longitude: CLLocationDegrees,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]? = nil,
        experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?],
        additionalTags: [String : String] = [:]
    ) {
        self.id = id
        self.version = version
        self.oswElementClass = oswElementClass
        self.latitude = latitude
        self.longitude = longitude
        self.attributeValues = attributeValues
        self.calculatedAttributeValues = calculatedAttributeValues
        self.experimentalAttributeValues = experimentalAttributeValues
        self.additionalTags = additionalTags
    }
    
    init(
        osmNode: OSMNode,
        oswElementClass: OSWElementClass
    ) {
        self.id = osmNode.id
        self.version = osmNode.version
        self.oswElementClass = oswElementClass
        self.latitude = osmNode.latitude
        self.longitude = osmNode.longitude
        self.attributeValues = [:]
        self.calculatedAttributeValues = [:]
        self.experimentalAttributeValues = [:]
        /// NOTE: Some tags might actually correspond to attribute values, but these will be overwritten when the attribute values are set.
        /// The OSM xml functions are designed such that attribute value tags take precedence over additional tags, so this should not cause any issues.
        self.additionalTags = osmNode.tags
    }
    
    func getCaptureId() -> String? {
        if let captureId = additionalTags[APIConstants.TagKeys.captureIdKey] {
            return captureId
        }
        return nil
    }
    
    var tags: [String: String] {
        var identifyingFieldTags: [String: String] = [:]
        if oswElementClass.geometry == .point {
            identifyingFieldTags = oswElementClass.identifyingFieldTags
        }
        let attributeTags = getTagsFromAttributeValues(attributeValues: attributeValues)
        let experimentalAttributeTags = getTagsFromAttributeValues(attributeValues: experimentalAttributeValues)
        var calculatedAttributeTags: [String: String] = [:]
        if let calculatedAttributeValues {
            calculatedAttributeTags = getTagsFromAttributeValues(attributeValues: calculatedAttributeValues, isCalculated: true)
        }
        /**
         The merging strategy for tags is to prioritize as follows (high to low):
            1. Identifying Field Tags: These are derived from the OSWElementClass and are essential for defining the type of element.
            2. Attribute Tags: These are derived from the attribute values of the element.
            3. Experimental Attribute Tags: These are derived from the experimental attribute values and may represent new or in-testing features.
            4. Calculated Attribute Tags: These are derived from calculated attribute values and may represent attributes that are not directly set but inferred from other data.
            5. Additional Tags: These are any extra tags that may be added for specific use cases or to provide additional context.
         */
        let tags = identifyingFieldTags.merging(attributeTags) { old, new in
            return old
        }.merging(experimentalAttributeTags) { old, new in
            return old
        }.merging(calculatedAttributeTags) { old, new in
            return old
        }.merging(additionalTags) { old, new in
            return old
        }
        return tags
    }
    
    private func getTagsFromAttributeValues(
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        isCalculated: Bool = false
    ) -> [String: String] {
        var attributeTags: [String: String] = [:]
        attributeValues.forEach { attributeKeyValuePair in
            let attributeKey = attributeKeyValuePair.key
            var attributeTagKey = attributeKey.osmTagKey
            if isCalculated {
                attributeTagKey = "\(APIConstants.TagKeys.calculatedTagPrefix):\(attributeTagKey)"
            }
            let attributeValue = attributeKeyValuePair.value
            let attributeTagValue = attributeKey.getValueDescription(attributeValue: attributeValue)
            guard let attributeTagValue else { return }
            attributeTags[attributeTagKey] = attributeTagValue
        }
        return attributeTags
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
    
    var detailedDescription: String {
        /// This includes all immediate details of the OSWPoint, including the OSWElementClass and all tags, but does not include the details of the OSWElementClass's identifying field tags.
        let tagsDescription = tags.map { "\($0): \($1)" }.joined(separator: ", ")
        return "OSWPoint(id: \(id), version: \(version), latitude: \(latitude), longitude: \(longitude), tags: [\(tagsDescription)])"
    }
}
