//
//  FeatureGeometry.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/26.
//

public enum FeatureGeometry: String, CaseIterable, Hashable, Codable {
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

public extension FeatureGeometry {
    static let `default`: FeatureGeometry = .point
}
