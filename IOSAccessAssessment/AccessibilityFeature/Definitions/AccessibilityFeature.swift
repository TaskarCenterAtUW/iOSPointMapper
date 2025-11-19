//
//  AnnotatedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/18/25.
//

enum AccessibilityFeatureError: Error, LocalizedError {
    case attributeValueMismatch(attribute: AccessibilityFeatureAttribute, value: AccessibilityFeatureAttributeValue)
    
    var errorDescription: String? {
        switch self {
        case .attributeValueMismatch(let attribute, let value):
            return "The value \(value) does not match the expected type for attribute \(attribute)."
        }
    }
}

class AccessibilityFeature {
    let accessibilityFeatureClass: AccessibilityFeatureClass
    
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttributeValue] = [:]
    var finalAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttributeValue] = [:]
    
    init(accessibilityFeatureClass: AccessibilityFeatureClass) {
        self.accessibilityFeatureClass = accessibilityFeatureClass
        
        calculatedAttributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.attributes.map { attribute in
            return (attribute, attribute.nilValue)
        })
        finalAttributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.attributes.map { attribute in
            return (attribute, attribute.nilValue)
        })
    }
    
    func setValue(
        _ value: AccessibilityFeatureAttributeValue,
        for attribute: AccessibilityFeatureAttribute,
        isCalculated: Bool = false
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        if isCalculated {
            calculatedAttributeValues[attribute] = value
            if (finalAttributeValues[attribute] == attribute.nilValue) { finalAttributeValues[attribute] = value }
        } else {
            finalAttributeValues[attribute] = value
        }
    }
}
