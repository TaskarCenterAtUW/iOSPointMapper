//
//  CategoricalAttribute.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/12/26.
//

import Foundation

public protocol FeatureCategorical: Codable, CaseIterable, Sendable, RawRepresentable where RawValue == String {
    static var typeID: String { get }   // unique identifier
}

public struct AnyCategoricalValue: Codable, Sendable, Equatable, Hashable {
    public let typeID: String
    public let rawValue: String
    
    public init(typeID: String, rawValue: String) {
        self.typeID = typeID
        self.rawValue = rawValue
    }
    
    public init<T: FeatureCategorical>(_ value: T) {
        self.typeID = T.typeID
        self.rawValue = value.rawValue
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.typeID = try container.decode(String.self, forKey: .typeID)
        self.rawValue = try container.decode(String.self, forKey: .rawValue)
    }
    
    public func value<T: FeatureCategorical>(as type: T.Type) -> T? {
        guard type.typeID == self.typeID else {
            return nil
        }
        return T(rawValue: self.rawValue)
    }
}

public enum SurfaceIntegrityStatus: String, FeatureCategorical, Comparable {
    case intact
    case slight
    case moderate
    case severe
    
    /// - Warning: This typeID must not be changed, as it is used to locally store accessibilty feature details, and changing this would break the decoding of existing data
    /// . If you need to change the typeID for some reason, please implement a migration strategy to update existing stored data with the new typeID.
    public static let typeID = "surface_integrity_status"
    
    public static func < (lhs: SurfaceIntegrityStatus, rhs: SurfaceIntegrityStatus) -> Bool {
        switch (lhs, rhs) {
        case (.intact, .slight), (.intact, .moderate), (.intact, .severe),
            (.slight, .moderate), (.slight, .severe),
            (.moderate, .severe):
            return true
        default:
            return false
        }
    }
}

/**
 A registry for categorical attributes that allows for dynamic registration and decoding of categorical types based on their unique type identifiers.
 This enables the system to support a wide range of categorical attributes without hardcoding each type, making it extensible and adaptable to future needs.
 */
public struct CategoricalAttributeRegistry {
    
    private static var decoders: [String: (String) -> Any?] = [:]
    private static var allCases: [String: () -> [AnyCategoricalValue]] = [:]
    
    public static func register<T: FeatureCategorical>(
        _ type: T.Type
    ) {
        decoders[T.typeID] = { raw in
            return T(rawValue: raw)
        }
        allCases[T.typeID] = {
            return T.allCases.map { AnyCategoricalValue($0) }
        }
    }
    
    public static func registerAll() {
        register(SurfaceIntegrityStatus.self)
    }
    
    public static func decode(typeID: String, raw: String) -> Any? {
        return decoders[typeID]?(raw)
    }
    
    public static func decodeToCategoricalValue(typeID: String, raw: String) -> AnyCategoricalValue? {
        guard let _ = decode(typeID: typeID, raw: raw) else {
            return nil
        }
        return AnyCategoricalValue(typeID: typeID, rawValue: raw)
    }
    
    public static func cases(for typeID: String) -> [AnyCategoricalValue]? {
        return allCases[typeID]?()
    }
}
