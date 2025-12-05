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
    
    var location: CLLocationCoordinate2D?
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    
    init(
        id: UUID = UUID(),
        detectedAccessibilityFeature: DetectedAccessibilityFeature
    ) {
        self.id = id
        self.accessibilityFeatureClass = detectedAccessibilityFeature.accessibilityFeatureClass
        self.contourDetails = detectedAccessibilityFeature.contourDetails
        
        self.location = nil
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
        location: CLLocationCoordinate2D?,
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    ) {
        self.id = id
        self.contourDetails = contourDetails
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.location = location
        self.attributeValues = attributeValues
    }
    
    func setAnnotationOption(_ option: AnnotationOption) {
        self.selectedAnnotationOption = option
    }
    
    func setLocation(_ location: CLLocationCoordinate2D?) {
        self.location = location
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
