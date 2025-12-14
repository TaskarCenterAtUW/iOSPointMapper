//
//  AccessibilityFeatureAttribute.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation

/**
    Enumeration defining various accessibility feature attributes, along with their metadata and value types.
 
    - Note: One needs to be aware of the value types associated with each attribute. The valueType property is only meant for reference.
 */
enum AccessibilityFeatureAttribute: String, Identifiable, CaseIterable, Codable, Sendable, Comparable {
    case width
    case runningSlope
    case crossSlope
    case surfaceIntegrity
    /**
     - NOTE:
     Experimental attributes
     */
    case lidarDepth
    
    enum Value: Sendable, Codable, Equatable {
        case length(Measurement<UnitLength>)
        case angle(Measurement<UnitAngle>)
        case flag(Bool)
        
        static func == (lhs: Value, rhs: Value) -> Bool {
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
    
    struct Metadata {
        let id: Int
        let name: String
        let unit: Dimension?
        let valueType: Value
        /// TODO: Verify these OSM tag keys
        let osmTagKey: String
    }
    
    private var metadata: Metadata {
        switch self {
        case .width:
            return Metadata(
                id: 10, name: "Width", unit: UnitLength.meters,
                valueType: .length(Measurement(value: 0, unit: .meters)),
                osmTagKey: "width"
            )
        case .runningSlope:
            return Metadata(
                id: 20, name: "Running Slope", unit: UnitAngle.degrees,
                valueType: .angle(Measurement(value: 0, unit: .degrees)),
                osmTagKey: "incline"
            )
        case .crossSlope:
            return Metadata(
                id: 30, name: "Cross Slope", unit: UnitAngle.degrees,
                valueType: .angle(Measurement(value: 0, unit: .degrees)),
                osmTagKey: "cross_slope"
            )
        case .surfaceIntegrity:
            return Metadata(
                id: 40, name: "Surface Integrity", unit: nil,
                valueType: .flag(false),
                osmTagKey: "surface"
            )
        case .lidarDepth:
            return Metadata(
                id: 50, name: "LiDAR Depth", unit: UnitLength.meters,
                valueType: .length(Measurement(value: 0, unit: .meters)),
                osmTagKey: APIConstants.TagKeys.lidarDepthKey
            )
        }
    }
    
    var id: Int {
        return metadata.id
    }
    
    var name: String {
        return metadata.name
    }
    
    var unit: Dimension? {
        return metadata.unit
    }
    
    var displayName: String {
        if let unit = unit {
            return "\(name) (\(unit.symbol))"
        } else {
            return name
        }
    }
    
    /// TODO: Verify these OSM tag keys
    var osmTagKey: String {
        return metadata.osmTagKey
    }
    
    static func < (lhs: AccessibilityFeatureAttribute, rhs: AccessibilityFeatureAttribute) -> Bool {
        return lhs.id < rhs.id
    }
}

/**
 Extensions for AccessibilityFeatureAttribute to provide expected value types,
 */
extension AccessibilityFeatureAttribute {
    func isCompatible(with value: Value) -> Bool {
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

/**
 Extension to convert AccessibilityFeatureAttribute.Value to and from primitive types.
 */
extension AccessibilityFeatureAttribute.Value {
    func toDouble() -> Double? {
        switch self {
        case .length(let measurement):
            return measurement.converted(to: .meters).value
        case .angle(let measurement):
            return measurement.converted(to: .degrees).value
        case .flag:
            return nil
        }
    }
    
    func toBool() -> Bool? {
        switch self {
        case .flag(let value):
            return value
        default:
            return nil
        }
    }
}

extension AccessibilityFeatureAttribute {
    func valueFromDouble(_ value: Double) -> Value? {
        switch self {
        case .width:
            return .length(Measurement(value: value, unit: .meters))
        case .runningSlope:
            return .angle(Measurement(value: value, unit: .degrees))
        case .crossSlope:
            return .angle(Measurement(value: value, unit: .degrees))
        case .surfaceIntegrity:
            return nil // Surface Integrity does not have a double representation
        case .lidarDepth:
            return .length(Measurement(value: value, unit: .meters))
        }
    }
    
    func valueFromBool(_ value: Bool) -> Value? {
        switch self {
        case .surfaceIntegrity:
            return .flag(value)
        default:
            return nil // Other attributes do not have a boolean representation
        }
    }
    
    func getOSMTagFromValue(attributeValue: Value?) -> String? {
        guard let attributeValue = attributeValue else {
            return nil
        }
        switch (self, attributeValue) {
        case (.width, .length(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .meters).value)
        case (.runningSlope, .angle(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .degrees).value)
        case (.crossSlope, .angle(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .degrees).value)
        case (.surfaceIntegrity, .flag(let flag)):
            return flag ? "yes" : "no"
        default:
            return nil
        }
    }
}
