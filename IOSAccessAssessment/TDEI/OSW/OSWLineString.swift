//
//  OSWLineString.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/9/25.
//

import Foundation
import CoreLocation

struct OSWLineString: OSWElement {
    let osmElementType: OSMElementType = .way
    
    let id: String
    let version: String
    let oswElementClass: OSWElementClass
    
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]? = [:]
    var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    var additionalTags: [String : String] = [:]
    
    var points: [OSWPoint]
    
    init(
        id: String, version: String,
        oswElementClass: OSWElementClass,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]? = nil,
        experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?],
        points: [OSWPoint],
        additionalTags: [String : String] = [:]
    ) {
        self.id = id
        self.version = version
        self.oswElementClass = oswElementClass
        self.attributeValues = attributeValues
        self.calculatedAttributeValues = calculatedAttributeValues
        self.experimentalAttributeValues = experimentalAttributeValues
        self.points = points
        self.additionalTags = additionalTags
    }
    
    /**
        Initializes an OSWLineString from an OSMWay and its associated OSMNodes.
     
        - Parameters:
            - osmWay: The OSMWay object representing the way element from OpenStreetMap.
            - oswElementClass: The OSWElementClass that defines the classification of the way element.
            - osmNodes: An array of OSMNode objects that are associated with the OSMWay. These nodes generally represent the points that make up the way. But they may contain additional nodes that are not part of the way, so we filter them based on the node references in the OSMWay.
     */
    init(
        osmWay: OSMWay,
        oswElementClass: OSWElementClass,
        osmNodes: [OSMNode]
    ) {
        self.id = osmWay.id
        self.version = osmWay.version
        self.oswElementClass = oswElementClass
        self.attributeValues = [:]
        self.calculatedAttributeValues = [:]
        self.experimentalAttributeValues = [:]
        let nodeRefs = osmWay.nodeRefs
        let osmNodeDict = Dictionary(uniqueKeysWithValues: osmNodes.map { ($0.id, $0) })
        /// The creation of points should be in the same order as node references in the way, not the osmNodes list
        var points: [OSWPoint] = []
        nodeRefs.forEach { nodeRef in
            if let osmNode = osmNodeDict[nodeRef] {
                let point = OSWPoint(osmNode: osmNode, oswElementClass: oswElementClass)
                points.append(point)
            }
        }
        self.points = points
        self.additionalTags = osmWay.tags
    }
    
    func getOSMLocationDetails() -> OSMLocationDetails? {
        let coordinates: [CLLocationCoordinate2D] = self.points.map { point in
            return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
        }
        let osmLocationElement: OSMLocationElement = OSMLocationElement(
            coordinates: coordinates, isWay: true, isClosed: false
        )
        return OSMLocationDetails(locations: [osmLocationElement])
    }
    
    var tags: [String: String] {
        var identifyingFieldTags: [String: String] = [:]
        if oswElementClass.geometry == .linestring {
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
            let attributeTagValue = attributeKey.getOSMTagFromValue(attributeValue: attributeValue)
            guard let attributeTagValue else { return }
            attributeTags[attributeTagKey] = attributeTagValue
        }
        return attributeTags
    }
    
    func toOSMCreateXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let refsXML = points.map { "<nd ref=\"\($0.id)\" />" }.joined(separator: "\n")
        let nodesXML = getUniquePoints().map { $0.toOSMCreateXML(changesetId: changesetId) }.joined(separator: "\n")
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
        let nodesXML = getUniquePoints().map { $0.toOSMModifyXML(changesetId: changesetId) }.joined(separator: "\n")
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
    
    private func getUniquePoints() -> [OSWPoint] {
        var uniquePoints: [OSWPoint] = []
        var seenPointIds: Set<String> = Set()
        self.points.forEach { point in
            if !seenPointIds.contains(point.id) {
                uniquePoints.append(point)
                seenPointIds.insert(point.id)
            }
        }
        return uniquePoints
    }
}
