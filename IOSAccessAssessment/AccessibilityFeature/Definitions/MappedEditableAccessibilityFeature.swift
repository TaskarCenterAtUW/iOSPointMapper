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
    
    var nearestOSWElements: [(any OSWElement, CLLocationDistance)]?
    var selectedNearestOSWElement: (any OSWElement, CLLocationDistance)?
    var selectedNearestOSWElementIndex: Int? {
        guard let selectedNearestOSWElement else { return nil }
        return nearestOSWElements?.firstIndex(where: { $0.0.id == selectedNearestOSWElement.0.id })
    }
    var isCorrectOSWElementSelected: Bool = true
    
    /// Corrected location-based adhoc details
    var correctedLocationDetails: LocationDetails?
    var correctedIsExisting: Bool = false
    var correctedOSWElement: (any OSWElement)?
    var correctedNearestOSWElements: [(any OSWElement, CLLocationDistance)]?
    var correctedSelectedNearestOSWElement: (any OSWElement, CLLocationDistance)?
    var correctedSelectedNearestOSWElementIndex: Int? {
        guard let correctedSelectedNearestOSWElement else { return nil }
        return correctedNearestOSWElements?.firstIndex(where: { $0.0.id == correctedSelectedNearestOSWElement.0.id })
    }
    var correctedIsCorrectOSWElementSelected: Bool = true
    
    /// Ambiguity cases
    var ambiguityCases: [AmbiguityCase] = []
    
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
        nearestOSWElements: [(any OSWElement, CLLocationDistance)]? = nil,
        selectedNearestOSWElement: (any OSWElement, CLLocationDistance)? = nil,
        isCorrectOSWElementSelected: Bool = true,
        correctedLocationDetails: LocationDetails? = nil,
        correctedIsExisting: Bool = false,
        correctedOSWElement: (any OSWElement)? = nil,
        correctedNearestOSWElements: [(any OSWElement, CLLocationDistance)]? = nil,
        correctedSelectedNearestOSWElement: (any OSWElement, CLLocationDistance)? = nil,
        correctedIsCorrectOSWElementSelected: Bool = true,
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
    
    func setSelectedNearestOSWElement(selectedNearestOSWElement: (any OSWElement, CLLocationDistance)?) {
        self.selectedNearestOSWElement = selectedNearestOSWElement
    }
    
    func setIsCorrectOSWElementSelected(_ isCorrectOSWElementSelected: Bool) {
        self.isCorrectOSWElementSelected = isCorrectOSWElementSelected
    }
    
    func setCorrectedLocationDetails(_ correctedLocationDetails: LocationDetails?) {
        self.correctedLocationDetails = correctedLocationDetails
    }
    
    func setCorrectedIsExisting(_ correctedIsExisting: Bool) {
        self.correctedIsExisting = correctedIsExisting
    }
    
    func setCorrectedOSWElement(_ correctedOSWElement: (any OSWElement)?) {
        self.correctedOSWElement = correctedOSWElement
    }
    
    func setCorrectedNearestOSWElements(_ correctedNearestOSWElements: [(any OSWElement, CLLocationDistance)]?) {
        self.correctedNearestOSWElements = correctedNearestOSWElements
    }
    
    func setCorrectedSelectedNearestOSWElement(_ correctedSelectedNearestOSWElement: (any OSWElement, CLLocationDistance)?) {
        self.correctedSelectedNearestOSWElement = correctedSelectedNearestOSWElement
    }
    
    func setCorrectedIsCorrectOSWElementSelected(_ correctedIsCorrectOSWElementSelected: Bool) {
        self.correctedIsCorrectOSWElementSelected = correctedIsCorrectOSWElementSelected
    }
    
    func setAmbiguityCases(_ ambiguityCases: [AmbiguityCase]) {
        self.ambiguityCases = ambiguityCases
    }
    
    func addAmbiguityCase(_ ambiguityCase: AmbiguityCase) {
        if !ambiguityCases.contains(where: { $0.rawValue == ambiguityCase.rawValue }) {
            self.ambiguityCases.append(ambiguityCase)
        }
    }
    
    func removeAmbiguityCase(_ ambiguityCase: AmbiguityCase) {
        self.ambiguityCases.removeAll(where: { $0.rawValue == ambiguityCase.rawValue })
    }
    
    public func getCorrectedLastLocationCoordinate() -> CLLocationCoordinate2D? {
        guard let correctedLocationDetails else { return nil }
        guard let lastCoordinate = correctedLocationDetails.locations.last?.coordinates.last else { return nil }
        return lastCoordinate
    }
    
    static func == (
        lhs: MappedEditableAccessibilityFeature, rhs: MappedEditableAccessibilityFeature
    ) -> Bool {
        return lhs.id == rhs.id
    }
}
