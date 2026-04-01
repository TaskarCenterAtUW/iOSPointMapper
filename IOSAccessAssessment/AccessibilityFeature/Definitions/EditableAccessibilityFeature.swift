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
    
    var locationDetails: OSMLocationDetails?
    /// If isExisting is false, even if an osw element is associated, it means the feature is new.
    /// If isExisting is true, it means the feature corresponds to an existing real-world feature, and the oswElement (if present) represents that existing feature in OSW.
    var isExisting: Bool = false
    var oswElement: (any OSWElement)?
    
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?] = [:]
    
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
        experimentalAttributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.experimentalAttributes.map { attribute in
            return (attribute, nil)
        })
    }
    
    init(
        id: UUID = UUID(),
        accessibilityFeatureClass: AccessibilityFeatureClass,
        contourDetails: ContourDetails,
        locationDetails: OSMLocationDetails?,
        isExisting: Bool = false,
        oswElement: (any OSWElement)? = nil,
        calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    ) {
        self.id = id
        self.contourDetails = contourDetails
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.locationDetails = locationDetails
        self.isExisting = isExisting
        self.oswElement = oswElement
        self.calculatedAttributeValues = calculatedAttributeValues
        self.attributeValues = attributeValues
        self.experimentalAttributeValues = experimentalAttributeValues
    }
    
    func setAnnotationOption(_ option: AnnotationOption) {
        self.selectedAnnotationOption = option
    }
    
    func getLastLocationCoordinate() -> CLLocationCoordinate2D? {
        guard let locationDetails else { return nil }
        guard let lastCoordinate = locationDetails.locations.last?.coordinates.last else { return nil }
        return lastCoordinate
    }
    
    func setLocationDetails(locationDetails: OSMLocationDetails) {
        self.locationDetails = locationDetails
    }
    
    func setIsExisting(_ isExisting: Bool) {
        self.isExisting = isExisting
    }
    
    func setOSWElement(oswElement: any OSWElement) {
        self.oswElement = oswElement
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
        attributeValues[attribute] = value
    }
    
    func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws {
        try setAttributeValue(value, for: attribute, isCalculated: false)
    }
    
    func setExperimentalAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        experimentalAttributeValues[attribute] = value
    }
    
    static func == (lhs: EditableAccessibilityFeature, rhs: EditableAccessibilityFeature) -> Bool {
        return lhs.id == rhs.id
    }
}
