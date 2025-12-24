//
//  AccessibilityFeatureFile.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/23/25.
//

import Foundation

struct AccessibilityFeatureFile: Codable {
    let frame: String
    let timestamp: TimeInterval
    
    var accessibilityFeatures: [AccessibilityFeatureSnapshot]
}
