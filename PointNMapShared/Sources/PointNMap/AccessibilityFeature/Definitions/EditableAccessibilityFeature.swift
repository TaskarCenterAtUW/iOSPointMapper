//
//  EditableAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/4/25.
//
import Foundation
import CoreLocation

public protocol EditableAccessibilityFeatureProtocol: AccessibilityFeatureProtocol, DetectedFeatureProtocol {
    var id: UUID { get }
    var selectedAnnotationOption: AnnotationOption { get set }
    var locationDetails: LocationDetails? { get set }
    var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] { get set }
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] { get set }
    var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?] { get set }
    
    init(
        id: UUID,
        detectedAccessibilityFeature: DetectedAccessibilityFeature
    )
    func setAnnotationOption(_ option: AnnotationOption)
    func getLastLocationCoordinate() -> CLLocationCoordinate2D?
    func setLocationDetails(locationDetails: LocationDetails)
    func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute,
        isCalculated: Bool,
        isFinal: Bool
    ) throws
    func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute,
        isCalculated: Bool
    ) throws
    func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws
    func setExperimentalAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws
}

open class EditableAccessibilityFeature: EditableAccessibilityFeatureProtocol {
    public let id: UUID
    
    public let accessibilityFeatureClass: AccessibilityFeatureClass
    
    public let contourDetails: ContourDetails
    
    public var selectedAnnotationOption: AnnotationOption = .individualOption(.default)
    
    public var locationDetails: LocationDetails?
    
    public var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    public var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
    public var experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?] = [:]
    
    public required init(
        id: UUID = UUID(),
        detectedAccessibilityFeature: DetectedAccessibilityFeature
    ) {
        self.id = id
        self.accessibilityFeatureClass = detectedAccessibilityFeature.accessibilityFeatureClass
        self.contourDetails = detectedAccessibilityFeature.contourDetails
        
        self.locationDetails = nil
        
        calculatedAttributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.kind.attributes.map { attribute in
            return (attribute, nil)
        })
        attributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.kind.attributes.map { attribute in
            return (attribute, nil)
        })
        experimentalAttributeValues = Dictionary(uniqueKeysWithValues: accessibilityFeatureClass.kind.experimentalAttributes.map { attribute in
            return (attribute, nil)
        })
    }
    
    public init(
        id: UUID = UUID(),
        accessibilityFeatureClass: AccessibilityFeatureClass,
        contourDetails: ContourDetails,
        locationDetails: LocationDetails?,
        calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    ) {
        self.id = id
        self.contourDetails = contourDetails
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.locationDetails = locationDetails
        self.calculatedAttributeValues = calculatedAttributeValues
        self.attributeValues = attributeValues
        self.experimentalAttributeValues = experimentalAttributeValues
    }
    
    public func setAnnotationOption(_ option: AnnotationOption) {
        self.selectedAnnotationOption = option
    }
    
    public func getLastLocationCoordinate() -> CLLocationCoordinate2D? {
        guard let locationDetails else { return nil }
        guard let lastCoordinate = locationDetails.locations.last?.coordinates.last else { return nil }
        return lastCoordinate
    }
    
    public func setLocationDetails(locationDetails: LocationDetails) {
        self.locationDetails = locationDetails
    }
    
    public func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute,
        isCalculated: Bool = false,
        isFinal: Bool = true
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        if isCalculated {
            calculatedAttributeValues[attribute] = value
        }
        if isFinal {
            attributeValues[attribute] = value
        }
    }
    
    public func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute,
        isCalculated: Bool = false
    ) throws {
        try setAttributeValue(value, for: attribute, isCalculated: isCalculated, isFinal: true)
    }
    
    public func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws {
        try setAttributeValue(value, for: attribute, isCalculated: false, isFinal: true)
    }
    
    public func setExperimentalAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws {
        guard attribute.isCompatible(with: value) else {
            throw AccessibilityFeatureError.attributeValueMismatch(attribute: attribute, value: value)
        }
        experimentalAttributeValues[attribute] = value
    }
    
    public static func == (lhs: EditableAccessibilityFeature, rhs: EditableAccessibilityFeature) -> Bool {
        return lhs.id == rhs.id
    }
}
