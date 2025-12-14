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
    
    var locationDetails: LocationDetails?
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    
    var oswElement: any OSWElement
    
    init (
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
    
    init(
        id: UUID = UUID(),
        accessibilityFeatureClass: AccessibilityFeatureClass,
        coordinates: [[CLLocationCoordinate2D]]?,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:],
        experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?] = [:],
        oswElement: any OSWElement
    ) {
        self.id = id
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.attributeValues = attributeValues
        self.experimentalAttributeValues = experimentalAttributeValues
        self.oswElement = oswElement
        guard let coordinates else { return }
        self.locationDetails = MappedAccessibilityFeature.getLocationDetails(
            from: coordinates, for: accessibilityFeatureClass
        )
    }
    
    static func getLocationDetails(
        from coordinates: [[CLLocationCoordinate2D]], for accessibilityFeatureClass: AccessibilityFeatureClass
    ) -> LocationDetails? {
        let oswElementClass = accessibilityFeatureClass.oswPolicy.oswElementClass
        switch(oswElementClass.geometry) {
        case .point:
            guard let firstCoordinate = coordinates.first?.first else { return nil }
            return LocationDetails(coordinates: [[firstCoordinate]])
        case .linestring:
            guard let firstLineCoordinates = coordinates.first else { return nil }
            return LocationDetails(coordinates: [firstLineCoordinates])
        case .polygon:
            return LocationDetails(coordinates: coordinates)
        }
    }
    
    func getLastLocationCoordinate() -> CLLocationCoordinate2D? {
        guard let locationDetails else { return nil }
        guard let lastCoordinate = locationDetails.coordinates.last?.last else { return nil }
        return lastCoordinate
    }
    
    mutating func setLocationDetails(coordinates: [[CLLocationCoordinate2D]]) {
        self.locationDetails = MappedAccessibilityFeature.getLocationDetails(
            from: coordinates, for: accessibilityFeatureClass
        )
    }
    
    mutating func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value, for attribute: AccessibilityFeatureAttribute
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        attributeValues[attribute] = value
    }
    
    mutating func setExperimentalAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value, for attribute: AccessibilityFeatureAttribute
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        experimentalAttributeValues[attribute] = value
    }
    
    mutating func setOSWElement(_ oswElement: any OSWElement) {
        self.oswElement = oswElement
    }
    
    static func == (lhs: MappedAccessibilityFeature, rhs: MappedAccessibilityFeature) -> Bool {
        return lhs.id == rhs.id
    }
    
    var description: String {
        return "MappedAccessibilityFeature(id: \(id), class: \(accessibilityFeatureClass), location: \(String(describing: locationDetails)), attributes: \(attributeValues), oswElement: \(oswElement))"
    }
}
