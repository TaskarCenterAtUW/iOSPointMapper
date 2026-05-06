//
//  MappingGeometry.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/26.
//

public enum MappingGeometry: String, CaseIterable, Hashable, Codable, Sendable {
    case point
    case linestring
    case polygon
    // case multipolygon // For future use, currently not supported by OSW API
    
    public var description: String {
        switch self {
        case .point:
            return "Point"
        case .linestring:
            return "LineString"
        case .polygon:
            return "Polygon"
        }
    }
}

public extension MappingGeometry {
    static let `default`: MappingGeometry = .point
}
