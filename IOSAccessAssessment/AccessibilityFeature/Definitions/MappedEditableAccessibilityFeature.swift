//
//  MappedEditableAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/1/26.
//
import Foundation
import CoreLocation
import PointNMapShared

class MappedEditableAccessibilityFeature: EditableAccessibilityFeature {
    /// If isExisting is false, even if an osw element is associated, it means the feature is new.
    /// If isExisting is true, it means the feature corresponds to an existing real-world feature, and the oswElement (if present) represents that existing feature in OSW.
    var isExisting: Bool = false
    var oswElement: (any OSWElement)?
    
    required init(
        id: UUID = UUID(),
        detectedAccessibilityFeature: DetectedAccessibilityFeature
    ) {
        super.init(id: id, detectedAccessibilityFeature: detectedAccessibilityFeature)
    }
    
    init(
        editableAccessibilityFeature: EditableAccessibilityFeature
    ) {
        self.isExisting = false
        self.oswElement = nil
        super.init(
            id: editableAccessibilityFeature.id,
            accessibilityFeatureClass: editableAccessibilityFeature.accessibilityFeatureClass,
            contourDetails: editableAccessibilityFeature.contourDetails,
            locationDetails: editableAccessibilityFeature.locationDetails,
            calculatedAttributeValues: editableAccessibilityFeature.calculatedAttributeValues,
            attributeValues: editableAccessibilityFeature.attributeValues,
            experimentalAttributeValues: editableAccessibilityFeature.experimentalAttributeValues
        )
    }
    
    init(
        id: UUID = UUID(),
        accessibilityFeatureClass: AccessibilityFeatureClass,
        contourDetails: ContourDetails,
        locationDetails: LocationDetails?,
        isExisting: Bool = false,
        oswElement: (any OSWElement)? = nil,
        calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?],
        experimentalAttributeValues: [AccessibilityFeatureAttribute : AccessibilityFeatureAttribute.Value?]
    ) {
        self.isExisting = isExisting
        self.oswElement = oswElement
        super.init(
            id: id,
            accessibilityFeatureClass: accessibilityFeatureClass,
            contourDetails: contourDetails,
            locationDetails: locationDetails,
            calculatedAttributeValues: calculatedAttributeValues,
            attributeValues: attributeValues,
            experimentalAttributeValues: experimentalAttributeValues
        )
    }
    
    func setIsExisting(_ isExisting: Bool) {
        self.isExisting = isExisting
    }
    
    func setOSWElement(oswElement: any OSWElement) {
        self.oswElement = oswElement
    }
    
    static func == (
        lhs: MappedEditableAccessibilityFeature, rhs: MappedEditableAccessibilityFeature
    ) -> Bool {
        return lhs.id == rhs.id
    }
}
