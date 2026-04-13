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
    case latitudeDelta
    case longitudeDelta
    /**
    - NOTE:
        Legacy attributes for comparison with older data
     */
    case widthLegacy
    case runningSlopeLegacy
    case crossSlopeLegacy
    case widthFromImage
    case runningSlopeFromImage
    case crossSlopeFromImage
    
    enum ValueType: Sendable, Codable, Equatable {
        case length
        case angle
        case flag
        case categorical(typeID: String)
    }
    
    enum Value: Sendable, Codable, Equatable {
        case length(Measurement<UnitLength>)
        case angle(Measurement<UnitAngle>)
        case flag(Bool)
        case categorical(AnyCategoricalValue)
        
        static func == (lhs: Value, rhs: Value) -> Bool {
            switch (lhs, rhs) {
            case (.length(let l1), .length(let l2)):
                return l1 == l2
            case (.angle(let a1), .angle(let a2)):
                return a1 == a2
            case (.flag(let f1), .flag(let f2)):
                return f1 == f2
            case (.categorical(let c1), .categorical(let c2)):
                return c1 == c2
            default:
                return false
            }
        }
    }
    
    struct Metadata {
        let id: Int
        let name: String
        let unit: Dimension?
        let valueType: ValueType
        /// TODO: Verify these OSM tag keys
        let osmTagKey: String
    }
    
    private var metadata: Metadata {
        switch self {
        case .width:
            return Metadata(
                id: 10, name: "Width", unit: UnitLength.meters,
                valueType: .length,
                osmTagKey: "width"
            )
        case .runningSlope:
            return Metadata(
                id: 20, name: "Running Slope", unit: UnitAngle.degrees,
                valueType: .angle,
                osmTagKey: "incline"
            )
        case .crossSlope:
            return Metadata(
                id: 30, name: "Cross Slope", unit: UnitAngle.degrees,
                valueType: .angle,
                osmTagKey: "cross_slope"
            )
        case .surfaceIntegrity:
            return Metadata(
                id: 40, name: "Surface Integrity", unit: nil,
                valueType: .categorical(typeID: SurfaceIntegrityStatus.typeID),
                osmTagKey: "surface_integrity"
            )
        case .lidarDepth:
            return Metadata(
                id: 50, name: "LiDAR Depth", unit: UnitLength.meters,
                valueType: .length,
                osmTagKey: APIConstants.TagKeys.lidarDepthKey
            )
        case .latitudeDelta:
            return Metadata(
                id: 60, name: "Latitude Delta", unit: UnitLength.meters,
                valueType: .length,
                osmTagKey: APIConstants.TagKeys.latitudeDeltaKey
            )
        case .longitudeDelta:
            return Metadata(
                id: 70, name: "Longitude Delta", unit: UnitLength.meters,
                valueType: .length,
                osmTagKey: APIConstants.TagKeys.longitudeDeltaKey
            )
        case .widthLegacy:
            return Metadata(
                id: 15, name: "Width Legacy", unit: UnitLength.meters,
                valueType: .length,
                osmTagKey: "width_legacy"
            )
        case .runningSlopeLegacy:
            return Metadata(
                id: 25, name: "Running Slope Legacy", unit: UnitAngle.degrees,
                valueType: .angle,
                osmTagKey: "incline_legacy"
            )
        case .crossSlopeLegacy:
            return Metadata(
                id: 35, name: "Cross Slope Legacy", unit: UnitAngle.degrees,
                valueType: .angle,
                osmTagKey: "cross_slope_legacy"
            )
        case .widthFromImage:
            return Metadata(
                id: 16, name: "Width from Image", unit: UnitLength.meters,
                valueType: .length,
                osmTagKey: "width_from_image"
            )
        case .runningSlopeFromImage:
            return Metadata(
                id: 26, name: "Running Slope from Image", unit: UnitAngle.degrees,
                valueType: .angle,
                osmTagKey: "running_slope_from_image"
            )
        case .crossSlopeFromImage:
            return Metadata(
                id: 36, name: "Cross Slope from Image", unit: UnitAngle.degrees,
                valueType: .angle,
                osmTagKey: "cross_slope_from_image"
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
    
    var valueType: ValueType {
        return metadata.valueType
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

extension AccessibilityFeatureAttribute.Value {
    var valueType: AccessibilityFeatureAttribute.ValueType {
        switch self {
        case .length: return .length
        case .angle: return .angle
        case .flag: return .flag
        case .categorical(let categoricalValue): return .categorical(typeID: categoricalValue.typeID)
        }
    }
}

/**
 Extensions for AccessibilityFeatureAttribute to provide expected value types,
 */
extension AccessibilityFeatureAttribute {
//    func isCompatible(with value: Value) -> Bool {
//        return self.valueType == value.valueType
//    }
    func isCompatible(with value: Value) -> Bool {
        switch (self.valueType, value) {
        case (.length, .length),
             (.angle, .angle),
             (.flag, .flag):
            return true
        case (.categorical(let expectedID), .categorical(let cat)):
            return cat.typeID == expectedID
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
        case .categorical:
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
    
    func toString() -> String? {
        switch self {
        case .length(let measurement):
            return String(format: "%.2f", measurement.converted(to: .meters).value)
        case .angle(let measurement):
            return String(format: "%.2f", measurement.converted(to: .degrees).value)
        case .flag(let value):
            return value ? "yes" : "no"
        case .categorical(let value):
            return value.rawValue
        }
    }
}

extension AccessibilityFeatureAttribute {
    func value(from double: Double) -> Value? {
        switch self.valueType {
        case .length:
            return .length(Measurement(value: double, unit: .meters))
        case .angle:
            return .angle(Measurement(value: double, unit: .degrees))
        case .flag:
            return nil // Flags cannot be represented as doubles
        case .categorical:
            return nil
        }
    }
    
    func value(from bool: Bool) -> Value? {
        switch self.valueType {
        case .flag:
            return .flag(bool)
        default:
            return nil // Only flags can be represented as booleans
        }
    }
    
    func value<T: FeatureCategorical>(from categorical: T) -> Value? {
        switch self.valueType {
        case .categorical(let expectedID):
            if T.typeID == expectedID {
                return .categorical(AnyCategoricalValue(categorical))
            } else {
                return nil // Categorical type ID does not match
            }
        default:
            return nil // Only categorical attributes can be represented as categorical values
        }
    }
    
    func value(from categoricalRawValue: String) -> Value? {
        switch self.valueType {
        case .categorical(let expectedID):
            switch expectedID {
            case SurfaceIntegrityStatus.typeID:
                if let categoricalValue = SurfaceIntegrityStatus(rawValue: categoricalRawValue) {
                    return .categorical(AnyCategoricalValue(categoricalValue))
                } else {
                    return nil // Invalid categorical raw value for Surface Integrity
                }
            default:
                guard let decoded = CategoricalAttributeRegistry.decodeToCategoricalValue(
                    typeID: expectedID,
                    raw: categoricalRawValue
                ) else {
                    return nil
                }
                return .categorical(decoded)
            }
        default:
            return nil // Only categorical attributes can be represented as categorical values
        }
    }
    
    func categoricalOptions() -> [AnyCategoricalValue] {
        guard case .categorical(let typeID) = self.valueType else {
            return []
        }
        if typeID == SurfaceIntegrityStatus.typeID {
            let options = SurfaceIntegrityStatus.allCases.map { AnyCategoricalValue($0) }
            return options
        }
        let options = CategoricalAttributeRegistry.cases(for: typeID) ?? []
        return options
    }
    
    func getValueDescription(attributeValue: Value?) -> String? {
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
        case (.surfaceIntegrity, .categorical(let categoricalValue)):
            return categoricalValue.rawValue
        case (.lidarDepth, .length(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .meters).value)
        case (.latitudeDelta, .length(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .meters).value)
        case (.longitudeDelta, .length(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .meters).value)
        case (.widthLegacy, .length(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .meters).value)
        case (.runningSlopeLegacy, .angle(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .degrees).value)
        case (.crossSlopeLegacy, .angle(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .degrees).value)
        case (.widthFromImage, .length(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .meters).value)
        case (.runningSlopeFromImage, .angle(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .degrees).value)
        case (.crossSlopeFromImage, .angle(let measurement)):
            return String(format: "%.2f", measurement.converted(to: .degrees).value)
        default:
            return nil
        }
    }
}
