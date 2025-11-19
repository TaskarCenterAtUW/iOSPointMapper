//
//  AccessibilityFeatureAttribute.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation

enum AccessibilityFeatureAttribute: String, CaseIterable, Codable, Sendable, Comparable {
    case width
    case runningSlope
    case crossSlope
    case surfaceIntegrity
    
    var id: Int {
        switch self {
        case .width:
            return 10
        case .runningSlope:
            return 20
        case .crossSlope:
            return 30
        case .surfaceIntegrity:
            return 40
        }
    }
    
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
    
    static func < (lhs: AccessibilityFeatureAttribute, rhs: AccessibilityFeatureAttribute) -> Bool {
        return lhs.id < rhs.id
    }
}

enum AccessibilityFeatureAttributeValue: Sendable, Codable, Equatable {
    case length(Measurement<UnitLength>)
    case angle(Measurement<UnitAngle>)
    case flag(Bool)
    
    static func == (lhs: AccessibilityFeatureAttributeValue, rhs: AccessibilityFeatureAttributeValue) -> Bool {
        switch (lhs, rhs) {
        case (.length(let l1), .length(let l2)):
            return l1 == l2
        case (.angle(let a1), .angle(let a2)):
            return a1 == a2
        case (.flag(let f1), .flag(let f2)):
            return f1 == f2
        default:
            return false
        }
    }
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
    
    var nilValue: AccessibilityFeatureAttributeValue {
        switch self {
        case .width:
            return .length(Measurement(value: -1, unit: .meters))
        case .runningSlope:
            return .angle(Measurement(value: -1, unit: .degrees))
        case .crossSlope:
            return .angle(Measurement(value: -1, unit: .degrees))
        case .surfaceIntegrity:
            return .flag(false)
        }
    }
    
    func isCompatible(with value: AccessibilityFeatureAttributeValue) -> Bool {
        switch (self, value) {
        case (.width, .length):
            return true
        case (.runningSlope, .angle):
            return true
        case (.crossSlope, .angle):
            return true
        case (.surfaceIntegrity, .flag):
            return true
        default:
            return false
        }
    }
}
