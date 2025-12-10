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

struct LocationDetails {
    var coordinates: [[CLLocationCoordinate2D]]
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinates = [[coordinate]]
    }
    
    init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = [coordinates]
    }
    
    init(coordinates: [[CLLocationCoordinate2D]]) {
        self.coordinates = coordinates
    }
}

protocol AccessibilityFeatureProtocol: Identifiable, Equatable {
    var id: UUID { get }
    
    var accessibilityFeatureClass: AccessibilityFeatureClass { get }
    
    var locationDetails: LocationDetails? { get set }
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] { get set }
    
    mutating func setLocationDetails(coordinates: [[CLLocationCoordinate2D]])
    
    mutating func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws
}
