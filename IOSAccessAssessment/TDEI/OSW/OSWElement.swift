//
//  OSWElement.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//
import Foundation
import CoreLocation
import PointNMapShared

enum OSWAttributeTagSerializer {
    static func tags(
        from attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        isCalculated: Bool = false
    ) -> [String: String] {
        attributeValues.reduce(into: [:]) { tags, entry in
            guard let value = entry.value,
                  let tagValue = value.primitiveValue.oswTagValue else {
                return
            }

            let baseKey = entry.key.osmTagKey
            let tagKey = isCalculated
                ? "\(APIConstants.TagKeys.calculatedTagPrefix):\(baseKey)"
                : baseKey
            tags[tagKey] = tagValue
        }
    }
}

protocol OSWElement: Sendable, CustomStringConvertible {
    var osmElementType: OSMElementType { get }
    
    var id: String { get }
    var version: String { get }
    
    var oswElementClass: OSWElementClass { get }
    
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] { get }
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]? { get }
    var experimentalAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] { get }
    var additionalTags: [String: String] { get }
    
    func getCaptureId() -> String?
    
    func toOSMCreateXML(changesetId: String) -> String
    func toOSMModifyXML(changesetId: String) -> String
    func toOSMDeleteXML(changesetId: String) -> String
    
    var shortDescription: String { get }
    var detailedDescription: String { get }
}
