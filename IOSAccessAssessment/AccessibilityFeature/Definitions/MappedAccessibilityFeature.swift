//
//  MappedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/4/25.
//
import Foundation
import CoreLocation

struct MappedAccessibilityFeature: AccessibilityFeatureProtocol, Sendable, CustomStringConvertible {
    let id: UUID
    
    let accessibilityFeatureClass: AccessibilityFeatureClass
    
    var location: CLLocationCoordinate2D?
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    
    var oswElement: any OSWElement
    
    init (
        id: UUID = UUID(),
        accessibilityFeature: (any AccessibilityFeatureProtocol),
        oswElement: any OSWElement
    ) {
        self.id = id
        self.accessibilityFeatureClass = accessibilityFeature.accessibilityFeatureClass
        self.location = accessibilityFeature.location
        self.attributeValues = accessibilityFeature.attributeValues
        self.oswElement = oswElement
    }
    
    init(
        id: UUID = UUID(),
        accessibilityFeatureClass: AccessibilityFeatureClass,
        location: CLLocationCoordinate2D?,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:],
        oswElement: any OSWElement
    ) {
        self.id = id
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.location = location
        self.attributeValues = attributeValues
        self.oswElement = oswElement
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
    
    mutating func setOSWElement(_ oswElement: any OSWElement) {
        self.oswElement = oswElement
    }
    
    static func == (lhs: MappedAccessibilityFeature, rhs: MappedAccessibilityFeature) -> Bool {
        return lhs.id == rhs.id
    }
    
    var description: String {
        return "MappedAccessibilityFeature(id: \(id), class: \(accessibilityFeatureClass), location: \(String(describing: location)), attributes: \(attributeValues), oswElement: \(oswElement))"
    }
}
