//
//  OSWMultiPolygon.swift
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
        return "<member type=\"\(element.osmElementType.rawValue)\" ref=\"\(element.id)\" role=\"\(role)\" />"
    }
}

/**
 - Warning:
 OSWMultiPolygon is not currently supported by OpenSidewalks schema. This is just a placeholder.
 */
struct OSWMultiPolygon: OSWElement {
    let osmElementType: OSMElementType = .relation
    
    let id: String
    let version: String
    let oswElementClass: OSWElementClass
    
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]? = [:]
    var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    var additionalTags: [String : String] = [:]
    
    /// TODO: Add the proper support for member (specifically roles).
    var members: [OSWRelationMember]
    
    init(
        id: String, version: String,
        oswElementClass: OSWElementClass,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]? = nil,
        experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?],
        members: [OSWRelationMember],
        additionalTags: [String : String] = [:]
    ) {
        self.id = id
        self.version = version
        self.oswElementClass = oswElementClass
        self.attributeValues = attributeValues
        self.calculatedAttributeValues = calculatedAttributeValues
        self.experimentalAttributeValues = experimentalAttributeValues
        self.members = members
        self.additionalTags = additionalTags
    }
    
    /**
     Initializes an OSWMultiPolygon from an OSMRelation and its member elements.
     
     - Parameters:
        - osmRelation: The OSMRelation object representing the relation element in OSM.
        - oswElementClass: The OSWElementClass corresponding to the relation's tags.
        - osmMemberElements: An array of OSWElement objects representing the members of the relation. This array can actually represent nested relations as discreet elements. This initializer is supposed to identify the members of the relation and assign them the correct roles.
     */
    init(
        osmRelation: OSMRelation,
        oswElementClass: OSWElementClass,
        osmMemberElements: [any OSMElement]
    ) {
        self.id = osmRelation.id
        self.version = osmRelation.version
        self.oswElementClass = oswElementClass
        self.attributeValues = [:]
        self.calculatedAttributeValues = [:]
        self.experimentalAttributeValues = [:]
        
        let osmMemberRefs: [OSMRelationMember] = osmRelation.members
        let osmNodeMemberRefs = osmMemberRefs.filter { $0.type == .node }
        let osmWayMemberRefs = osmMemberRefs.filter { $0.type == .way }
        let osmRelationMemberRefs = osmMemberRefs.filter { $0.type == .relation }
        
        let osmMemberElementsDict: [String: any OSMElement] = Dictionary(
            uniqueKeysWithValues: osmMemberElements.map { ($0.id, $0) }
        )
        let osmNodeElements: [OSMNode] = osmMemberElements.filter { element in
            return osmNodeMemberRefs.contains { $0.ref == element.id }
        }.compactMap { element in
            return element as? OSMNode
        }
        let osmNodeElementsDict: [String: OSMNode] = Dictionary(uniqueKeysWithValues: osmNodeElements.map { ($0.id, $0) })
        let osmWayElements: [OSMWay] = osmMemberElements.filter { element in
            return osmWayMemberRefs.contains { $0.ref == element.id }
        }.compactMap { element in
            return element as? OSMWay
        }
        let osmWayElementsDict: [String: OSMWay] = Dictionary(uniqueKeysWithValues: osmWayElements.map { ($0.id, $0) })
        let osmRelationElements: [OSMRelation] = osmMemberElements.filter { element in
            return osmRelationMemberRefs.contains { $0.ref == element.id }
        }.compactMap { element in
            return element as? OSMRelation
        }
        let osmRelationElementsDict: [String: OSMRelation] = Dictionary(
            uniqueKeysWithValues: osmRelationElements.map { ($0.id, $0) }
        )
        
        var oswRelationMembers: [OSWRelationMember] = []
        osmNodeMemberRefs.forEach { osmNodeMemberRef in
            if let matchingOSMNodeElement = osmNodeElementsDict[osmNodeMemberRef.ref] {
                let oswPoint: OSWPoint = OSWPoint(osmNode: matchingOSMNodeElement, oswElementClass: oswElementClass)
                let oswRelationMember = OSWRelationMember(element: oswPoint, role: osmNodeMemberRef.role)
                oswRelationMembers.append(oswRelationMember)
            }
        }
        osmWayMemberRefs.forEach { osmWayMemberRef in
            if let matchingOSMWayElement = osmWayElementsDict[osmWayMemberRef.ref] {
                let matchingOSWWayNodes = matchingOSMWayElement.nodeRefs.compactMap { nodeRef in
                    return osmNodeElementsDict[nodeRef]
                }
                let oswLineString: OSWLineString = OSWLineString(
                    osmWay: matchingOSMWayElement, oswElementClass: oswElementClass,
                    osmNodes: matchingOSWWayNodes
                )
                let oswRelationMember = OSWRelationMember(element: oswLineString, role: osmWayMemberRef.role)
                oswRelationMembers.append(oswRelationMember)
            }
        }
        osmRelationMemberRefs.forEach { osmRelationMemberRef in
            if let matchingOSMRelationElement = osmRelationElementsDict[osmRelationMemberRef.ref] {
                let matchingOSMRelationMemberElements = matchingOSMRelationElement.members.compactMap { memberRef in
                    return osmMemberElementsDict[memberRef.ref]
                }
                let oswMultiPolygon: OSWMultiPolygon = OSWMultiPolygon(
                    osmRelation: matchingOSMRelationElement, oswElementClass: oswElementClass,
                    osmMemberElements: matchingOSMRelationMemberElements
                )
                let oswRelationMember = OSWRelationMember(element: oswMultiPolygon, role: osmRelationMemberRef.role)
                oswRelationMembers.append(oswRelationMember)
            }
        }
        self.members = oswRelationMembers
        self.additionalTags = osmRelation.tags
    }
    
    /// TODO: This is a temporary implementation. The location details of a multipolygon relation can be determined in multiple ways (e.g. centroid of the polygon, location of a specific node member etc.). The proper strategy for determining the location details of a multipolygon relation needs to be defined and implemented.
    func getOSMLocationDetails() -> OSMLocationDetails? {
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
    
    /**
     - TODO:
     Depending on the type of polygon, add the polygon type tag (e.g. "type"="multipolygon") if required.
     */
    func toOSMCreateXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let membersXML = getUniqueMembers().map {
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
        let membersXML = getUniqueMembers().map {
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
        return "OSWMultiPolygon(id: \(id), version: \(version), class: \(oswElementClass), members: [\(membersString)])"
    }
    
    var shortDescription: String {
        return "OSWMultiPolygon(id: \(id))"
    }
    
    private func getUniqueMembers() -> [OSWRelationMember] {
        var uniqueMembers: [OSWRelationMember] = []
        var seenMemberIds: Set<String> = Set()
        self.members.forEach { member in
            if !seenMemberIds.contains(member.element.id) {
                uniqueMembers.append(member)
                seenMemberIds.insert(member.element.id)
            }
        }
        return uniqueMembers
    }
}
