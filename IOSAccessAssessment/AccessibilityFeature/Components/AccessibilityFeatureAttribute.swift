//
//  AccessibilityFeatureAttribute.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation

enum AccessibilityFeatureAttribute: String, CaseIterable, Codable, Sendable {
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

enum AccessibilityFeatureAttributeValue: Sendable, Codable {
    case length(Measurement<UnitLength>)
    case angle(Measurement<UnitAngle>)
    case flag(Bool)
}

extension AccessibilityFeatureAttribute {
    var expectedValueType: AccessibilityFeatureAttributeValue {
        switch self {
        case .width:
            return .length(Measurement(value: 0, unit: .meters))
        case .runningSlope:
            return .angle(Measurement(value: 0, unit: .degrees))
        case .crossSlope:
            return .angle(Measurement(value: 0, unit: .degrees))
        case .surfaceIntegrity:
            return .flag(false)
        }
    }
}
