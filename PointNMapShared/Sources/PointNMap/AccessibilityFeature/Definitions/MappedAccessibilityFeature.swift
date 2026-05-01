//
//  MappedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/4/25.
//
import Foundation
import CoreLocation

public struct MappedAccessibilityFeature: AccessibilityFeatureProtocol, Sendable, CustomStringConvertible {
    public let id: UUID
    
    public let accessibilityFeatureClass: AccessibilityFeatureClass
    
    public var locationDetails: LocationDetails?
    public var oswElement: any OSWElement
    
    public var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    public var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    
    public init (
        id: UUID = UUID(),
        accessibilityFeature: (any AccessibilityFeatureProtocol),
        oswElement: any OSWElement
    ) {
        self.id = id
        self.accessibilityFeatureClass = accessibilityFeature.accessibilityFeatureClass
        self.locationDetails = accessibilityFeature.locationDetails
        self.attributeValues = accessibilityFeature.attributeValues
        self.experimentalAttributeValues = accessibilityFeature.experimentalAttributeValues
        self.oswElement = oswElement
    }
    
    public init(
        id: UUID = UUID(),
        accessibilityFeatureClass: AccessibilityFeatureClass,
        locationDetails: LocationDetails?,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:],
        experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?] = [:],
        oswElement: any OSWElement
    ) {
        self.id = id
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.attributeValues = attributeValues
        self.experimentalAttributeValues = experimentalAttributeValues
        self.oswElement = oswElement
        self.locationDetails = locationDetails
    }
    
    public func getLastLocationCoordinate() -> CLLocationCoordinate2D? {
        guard let locationDetails else { return nil }
        guard let lastCoordinate = locationDetails.locations.last?.coordinates.last else { return nil }
        return lastCoordinate
    }
    
    public mutating func setLocationDetails(locationDetails: LocationDetails) {
        self.locationDetails = locationDetails
    }
    
    public mutating func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value, for attribute: AccessibilityFeatureAttribute
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        attributeValues[attribute] = value
    }
    
    public mutating func setExperimentalAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value, for attribute: AccessibilityFeatureAttribute
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        experimentalAttributeValues[attribute] = value
    }
    
    public mutating func setOSWElement(_ oswElement: any OSWElement) {
        self.oswElement = oswElement
    }
    
    public static func == (lhs: MappedAccessibilityFeature, rhs: MappedAccessibilityFeature) -> Bool {
        return lhs.id == rhs.id
    }
    
    public var description: String {
        return "MappedAccessibilityFeature(id: \(id), class: \(accessibilityFeatureClass), location: \(String(describing: locationDetails)), attributes: \(attributeValues), oswElement: \(oswElement))"
    }
}
