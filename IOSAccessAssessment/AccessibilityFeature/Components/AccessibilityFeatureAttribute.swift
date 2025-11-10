//
//  AccessibilityFeatureAttribute.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation

enum AccessibilityFeatureCalculatedAttribute: String, CaseIterable, Codable, Sendable {
    case width
    case runningSlope
    case crossSlope
    case surfaceIntegrity
    
    var displayName: String {
        switch self {
        case .width:
            return "Width"
        case .runningSlope:
            return "Running Slope"
        case .crossSlope:
            return "Cross Slope"
        case .surfaceIntegrity:
            return "Surface Integrity"
        }
    }
    
    var unit: String? {
        switch self {
        case .width:
            return "m"
        case .runningSlope, .crossSlope:
            return "°"
        case .surfaceIntegrity:
            return nil
        }
    }
}
