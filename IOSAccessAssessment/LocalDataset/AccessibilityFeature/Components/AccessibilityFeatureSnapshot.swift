//
//  AccessibilityFeatureSnapshot.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/23/25.
//

import Foundation
import CoreLocation

struct AccessibilityFeatureSnapshot: Codable, Identifiable, Sendable {
    let id: UUID
    
    let accessibilityFeatureClass: AccessibilityFeatureClassSnapshot
    
    let contourDetails: ContourDetails
    
    var selectedAnnotationOption: String
    
    var locationDetails: LocationDetails?
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?]
    var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    
    var oswElement: String?
    
    init(from accessibilityFeature: EditableAccessibilityFeature) {
        self.id = accessibilityFeature.id
        self.accessibilityFeatureClass = .init(from: accessibilityFeature.accessibilityFeatureClass)
        self.contourDetails = accessibilityFeature.contourDetails
        self.selectedAnnotationOption = accessibilityFeature.selectedAnnotationOption.rawValue
        self.locationDetails = accessibilityFeature.locationDetails
        self.calculatedAttributeValues = accessibilityFeature.calculatedAttributeValues
        self.attributeValues = accessibilityFeature.attributeValues
        self.experimentalAttributeValues = accessibilityFeature.experimentalAttributeValues
    }
    
    mutating func update(from accessibilityFeature: EditableAccessibilityFeature) {
        self.selectedAnnotationOption = accessibilityFeature.selectedAnnotationOption.rawValue
        self.locationDetails = accessibilityFeature.locationDetails
        self.calculatedAttributeValues = accessibilityFeature.calculatedAttributeValues
        self.attributeValues = accessibilityFeature.attributeValues
        self.experimentalAttributeValues = accessibilityFeature.experimentalAttributeValues
    }
    
    mutating func update(from accessibilityFeature: MappedAccessibilityFeature) {
        self.locationDetails = accessibilityFeature.locationDetails
        self.attributeValues = accessibilityFeature.attributeValues
        self.experimentalAttributeValues = accessibilityFeature.experimentalAttributeValues
        self.oswElement = accessibilityFeature.oswElement.id
    }
}
