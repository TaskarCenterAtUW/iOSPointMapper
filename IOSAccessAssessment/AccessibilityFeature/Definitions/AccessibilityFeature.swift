//
//  AnnotatedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/18/25.
//
import Foundation
import CoreLocation

enum AccessibilityFeatureError: Error, LocalizedError {
    case attributeValueMismatch(attribute: AccessibilityFeatureAttribute, value: AccessibilityFeatureAttribute.Value)
    
    var errorDescription: String? {
        switch self {
        case .attributeValueMismatch(let attribute, let value):
            return "The value \(value) does not match the expected type for attribute \(attribute)."
        }
    }
}

class AccessibilityFeature: Identifiable, Equatable {
    let id = UUID()
    
    let accessibilityFeatureClass: AccessibilityFeatureClass
    let detectedAccessibilityFeature: DetectedAccessibilityFeature
    
    var selectedAnnotationOption: AnnotationOption = .individualOption(.default)
    
    var calculatedLocation: CLLocationCoordinate2D?
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    var finalAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    
    init(
        accessibilityFeatureClass: AccessibilityFeatureClass,
        detectedAccessibilityFeature: DetectedAccessibilityFeature
    ) {
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.detectedAccessibilityFeature = detectedAccessibilityFeature
        
        calculatedAttributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.attributes.map { attribute in
            return (attribute, nil)
        })
        finalAttributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.attributes.map { attribute in
            return (attribute, nil)
        })
    }
    
    func setAnnotationOption(_ option: AnnotationOption) {
        self.selectedAnnotationOption = option
    }
    
    func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute,
        isCalculated: Bool = false
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        if isCalculated {
            calculatedAttributeValues[attribute] = value
        }
        finalAttributeValues[attribute] = value
    }
    
    static func == (lhs: AccessibilityFeature, rhs: AccessibilityFeature) -> Bool {
        return lhs.id == rhs.id
    }
}
