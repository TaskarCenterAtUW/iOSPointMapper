//
//  MappedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/4/25.
//
import Foundation
import CoreLocation

struct MappedAccessibilityFeature: Identifiable, Equatable, AccessibilityFeatureProtocol {
    let id: UUID
    
    let accessibilityFeatureClass: AccessibilityFeatureClass
    
    var location: CLLocationCoordinate2D?
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    
    var osmNode: OSMNode?
    
    init(
        id: UUID = UUID(),
        accessibilityFeatureClass: AccessibilityFeatureClass,
        location: CLLocationCoordinate2D?,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:],
        osmNode: OSMNode?
    ) {
        self.id = id
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.location = location
        self.attributeValues = attributeValues
        self.osmNode = osmNode
    }
    
    mutating func setLocation(_ location: CLLocationCoordinate2D?) {
        self.location = location
    }
    
    mutating func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value, for attribute: AccessibilityFeatureAttribute
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        attributeValues[attribute] = value
    }
    
    static func == (lhs: MappedAccessibilityFeature, rhs: MappedAccessibilityFeature) -> Bool {
        return lhs.id == rhs.id
    }
}
