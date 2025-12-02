//
//  AccessibilityFeatureAttribute.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation

enum AccessibilityFeatureAttribute: String, Identifiable, CaseIterable, Codable, Sendable, Comparable {
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
    
    var name: String {
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
    
    var displayName: String {
        if let unit = unit {
            return "\(name) (\(unit))"
        } else {
            return name
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

/**
 Extensions for AccessibilityFeatureAttribute to provide expected value types,
 */
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

extension AccessibilityFeatureAttribute {
    func getDouble(from attributeValue: AccessibilityFeatureAttributeValue?) -> Double {
        guard let attributeValue = attributeValue else {
            return -1
        }
        switch (self, attributeValue) {
        case (.width, .length(let measurement)):
            return measurement.converted(to: .meters).value
        case (.runningSlope, .angle(let measurement)):
            return measurement.converted(to: .degrees).value
        case (.crossSlope, .angle(let measurement)):
            return measurement.converted(to: .degrees).value
        case (.surfaceIntegrity, .flag(_)):
            return -1
        default:
            return -1
        }
    }
    
    func createFromDouble(_ value: Double) -> AccessibilityFeatureAttributeValue? {
        switch self {
        case .width:
            return .length(Measurement(value: value, unit: .meters))
        case .runningSlope:
            return .angle(Measurement(value: value, unit: .degrees))
        case .crossSlope:
            return .angle(Measurement(value: value, unit: .degrees))
        case .surfaceIntegrity:
            return nil // Surface Integrity does not have a double representation
        }
    }
    
    func getBool(from attributeValue: AccessibilityFeatureAttributeValue?) -> Bool {
        guard let attributeValue = attributeValue else {
            return false
        }
        switch (self, attributeValue) {
        case (.surfaceIntegrity, .flag(let flag)):
            return flag
        default:
            return false
        }
    }
    
    func createFromBool(_ value: Bool) -> AccessibilityFeatureAttributeValue? {
        switch self {
        case .surfaceIntegrity:
            return .flag(value)
        default:
            return nil // Only Surface Integrity uses Bool representation
        }
    }
}
