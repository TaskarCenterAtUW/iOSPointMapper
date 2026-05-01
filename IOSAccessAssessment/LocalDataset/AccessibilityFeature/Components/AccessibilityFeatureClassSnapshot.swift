//
//  AccessibilityFeatureClassSnapshot.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/23/25.
//

import Foundation
import CoreLocation
import PointNMapShared

struct AccessibilityFeatureClassSnapshot: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    
    init(from accessibilityFeatureClass: AccessibilityFeatureClass) {
        self.id = accessibilityFeatureClass.id
        self.name = accessibilityFeatureClass.name
    }
    
    /// Get AccessibilityFeatureClass from snapshot
    func getAccessibilityFeatureClass() -> AccessibilityFeatureClass? {
        let matchedClass = SharedAppConstants.SelectedAccessibilityFeatureConfig.classes.first { $0.id == self.id }
        return matchedClass
    }
}
