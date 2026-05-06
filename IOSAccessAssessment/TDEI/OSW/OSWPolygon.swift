//
//  OSWPolygon.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/9/25.
//

import Foundation
import CoreLocation
import PointNMapShared

struct OSWPolygon: OSWElement {
    let osmElementType: OSMElementType = .way
    
    let id: String
    let version: String
    let oswElementClass: OSWElementClass
    
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]? = [:]
    var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    var additionalTags: [String : String] = [:]
    
    var pointRefs: [String]
    
    init(
        id: String, version: String,
        oswElementClass: OSWElementClass,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]? = nil,
        experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?],
        pointRefs: [String],
        additionalTags: [String : String] = [:]
    ) {
        self.id = id
        self.version = version
        self.oswElementClass = oswElementClass
        self.attributeValues = attributeValues
        self.calculatedAttributeValues = calculatedAttributeValues
        self.experimentalAttributeValues = experimentalAttributeValues
        self.pointRefs = pointRefs
        self.additionalTags = additionalTags
        
        /// Re-update points to ensure the polygon is closed (i.e., first and last points are the same)
        self.pointRefs = getClosedPoints(oswPointRefs: pointRefs)
    }
    
    /**
        Initializes an OSWPolygon from an OSMWay and its associated OSMNodes.
     
        - Parameters:
            - osmWay: The OSMWay object representing the way element from OpenStreetMap.
            - oswElementClass: The OSWElementClass that defines the classification of the way element.
            - osmNodes: An array of OSMNode objects that are associated with the OSMWay. These nodes generally represent the points that make up the way. But they may contain additional nodes that are not part of the way, so we filter them based on the node references in the OSMWay.
     */
    init(
        osmWay: OSMWay,
        oswElementClass: OSWElementClass
    ) {
        self.id = osmWay.id
        self.version = osmWay.version
        self.oswElementClass = oswElementClass
        self.attributeValues = [:]
        self.calculatedAttributeValues = [:]
        self.experimentalAttributeValues = [:]
        let nodeRefs = osmWay.nodeRefs
        self.pointRefs = nodeRefs
        self.additionalTags = osmWay.tags
        
        /// Re-update points to ensure the polygon is closed (i.e., first and last points are the same)
        self.pointRefs = getClosedPoints(oswPointRefs: self.pointRefs)
    }
    
    func getClosedPoints(oswPointRefs: [String]) -> [String] {
        var closedPoints = oswPointRefs
        if let firstPoint = oswPointRefs.first, let lastPoint = oswPointRefs.last {
            if firstPoint != lastPoint {
                closedPoints.append(firstPoint)
            }
        }
        return closedPoints
    }
    
    func getCaptureId() -> String? {
        if let captureId = additionalTags[APIConstants.TagKeys.captureIdKey] {
            return captureId
        }
        return nil
    }
    
    var tags: [String: String] {
        var identifyingFieldTags: [String: String] = [:]
        if oswElementClass.geometry == .polygon {
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
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let refsXML = pointRefs.map { "<nd ref=\"\($0)\" />" }.joined(separator: "\n")
        return """
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
        let refsXML = pointRefs.map { "<nd ref=\"\($0)\" />" }.joined(separator: "\n")
        return """
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
        let nodesString = pointRefs.joined(separator: ", ")
        return "OSWLineString(id: \(id), version: \(version), nodes: [\(nodesString)])"
    }
    
    var shortDescription: String {
        return "OSWPolygon(id: \(id))"
    }
    
    var detailedDescription: String {
        /// This includes the point IDs and their coordinates for better debugging, but can be verbose if there are many points.
        let tagsDescription = tags.map { "\($0): \($1)" }.joined(separator: ", ")
        let nodesString = pointRefs.joined(separator: ", ")
        return """
        OSWLineString(
        id: \(id),
        version: \(version),
        tags: [\(tagsDescription)],
        nodes: [\(nodesString)]
        )
        """
    }
    
    private func getUniquePoints() -> [String] {
        var uniquePoints: [String] = []
        var seenPointIds: Set<String> = Set()
        self.pointRefs.forEach { pointRef in
            if !seenPointIds.contains(pointRef) {
                uniquePoints.append(pointRef)
                seenPointIds.insert(pointRef)
            }
        }
        return uniquePoints
    }
}
