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
        let tags = identifyingFieldTags.merging(attributeTags) { _, new in
            return new
        }.merging(experimentalAttributeTags) { _, new in
            return new
        }.merging(calculatedAttributeTags) { _, new in
            return new
        }.merging(additionalTags) { _, new in
            return new
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
        return "OSWPolygon(id: \(id), version: \(version), class: \(oswElementClass), members: [\(membersString)])"
    }
    
    var shortDescription: String {
        return "OSWPolygon(id: \(id))"
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
