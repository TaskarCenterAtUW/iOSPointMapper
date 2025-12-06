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

protocol AccessibilityFeatureProtocol: Identifiable, Equatable {
    var id: UUID { get }
    
    var accessibilityFeatureClass: AccessibilityFeatureClass { get }
    
    var location: CLLocationCoordinate2D? { get set }
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] { get set }
    
    mutating func setLocation(_ location: CLLocationCoordinate2D?)
    mutating func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws
}
