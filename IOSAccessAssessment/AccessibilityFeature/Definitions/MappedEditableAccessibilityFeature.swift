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
    
    var nearestOSWElements: [(any OSWElement, CLLocationDistance)] = []
    var isCorrectOSWElementSelected: Bool = false
    
    public var correctedLocationDetails: LocationDetails?
    var correctedIsExisting: Bool?
    var correctedOSWElement: (any OSWElement)?
    var correctedNearestOSWElements: [(any OSWElement, CLLocationDistance)]?
    var correctedIsCorrectOSWElementSelected: Bool?
    
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
        isCorrectOSWElementSelected: Bool = false,
        correctedLocationDetails: LocationDetails? = nil,
        correctedIsExisting: Bool? = nil,
        correctedOSWElement: (any OSWElement)? = nil,
        correctedNearestOSWElements: [(any OSWElement, CLLocationDistance)]? = nil,
        correctedIsCorrectOSWElementSelected: Bool? = nil,
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
    
    func setNearestOSWElements(nearestOSWElements: [(any OSWElement, CLLocationDistance)]) {
        self.nearestOSWElements = nearestOSWElements
    }
    
    func setIsCorrectOSWElementSelected(_ isCorrectOSWElementSelected: Bool) {
        self.isCorrectOSWElementSelected = isCorrectOSWElementSelected
    }
    
    func setCorrectedLocationDetails(_ correctedLocationDetails: LocationDetails?) {
        self.correctedLocationDetails = correctedLocationDetails
    }
    
    func setCorrectedIsExisting(_ correctedIsExisting: Bool?) {
        self.correctedIsExisting = correctedIsExisting
    }
    
    func setCorrectedOSWElement(_ correctedOSWElement: (any OSWElement)?) {
        self.correctedOSWElement = correctedOSWElement
    }
    
    func setCorrectedNearestOSWElements(_ correctedNearestOSWElements: [(any OSWElement, CLLocationDistance)]?) {
        self.correctedNearestOSWElements = correctedNearestOSWElements
    }
    
    func setCorrectedIsCorrectOSWElementSelected(_ correctedIsCorrectOSWElementSelected: Bool?) {
        self.correctedIsCorrectOSWElementSelected = correctedIsCorrectOSWElementSelected
    }
    
    static func == (
        lhs: MappedEditableAccessibilityFeature, rhs: MappedEditableAccessibilityFeature
    ) -> Bool {
        return lhs.id == rhs.id
    }
}
