//
//  EditableAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/4/25.
//
import Foundation
import CoreLocation

class EditableAccessibilityFeature: Identifiable, Equatable, AccessibilityFeatureProtocol, DetectedFeatureProtocol {
    let id: UUID
    
    let accessibilityFeatureClass: AccessibilityFeatureClass
    
    let contourDetails: ContourDetails
    
    var selectedAnnotationOption: AnnotationOption = .individualOption(.default)
    
    var locationDetails: LocationDetails?
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    
    init(
        id: UUID = UUID(),
        detectedAccessibilityFeature: DetectedAccessibilityFeature
    ) {
        self.id = id
        self.accessibilityFeatureClass = detectedAccessibilityFeature.accessibilityFeatureClass
        self.contourDetails = detectedAccessibilityFeature.contourDetails
        
        self.locationDetails = nil
        calculatedAttributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.attributes.map { attribute in
            return (attribute, nil)
        })
        attributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.attributes.map { attribute in
            return (attribute, nil)
        })
    }
    
    init(
        id: UUID = UUID(),
        accessibilityFeatureClass: AccessibilityFeatureClass,
        contourDetails: ContourDetails,
        coordinates: [[CLLocationCoordinate2D]]?,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    ) {
        self.id = id
        self.contourDetails = contourDetails
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.attributeValues = attributeValues
        
        guard let coordinates else { return }
        self.locationDetails = EditableAccessibilityFeature.getLocationDetails(
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
    
    func setAnnotationOption(_ option: AnnotationOption) {
        self.selectedAnnotationOption = option
    }
    
    func setLocationDetails(coordinates: [[CLLocationCoordinate2D]]) {
        self.locationDetails = EditableAccessibilityFeature.getLocationDetails(
            from: coordinates, for: accessibilityFeatureClass
        )
    }
    
    func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute,
        isCalculated: Bool
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        if isCalculated {
            calculatedAttributeValues[attribute] = value
        }
        attributeValues[attribute] = value
    }
    
    func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws {
        try setAttributeValue(value, for: attribute, isCalculated: false)
    }
    
    static func == (lhs: EditableAccessibilityFeature, rhs: EditableAccessibilityFeature) -> Bool {
        return lhs.id == rhs.id
    }
}
