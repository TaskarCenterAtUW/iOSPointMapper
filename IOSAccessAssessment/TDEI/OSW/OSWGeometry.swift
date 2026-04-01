//
//  OSWGeometry.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//

enum OSWGeometry: String, CaseIterable, Hashable, Codable {
    case point
    case linestring
    case polygon
    // case multipolygon // For future use, currently not supported by OSW API
    
    var description: String {
        switch self {
        case .point:
            return "Point"
        case .linestring:
            return "LineString"
        case .polygon:
            return "Polygon"
        }
    }
    
    var osmElementType: OSMElementType {
        switch self {
        case .point:
            return .node
        case .linestring:
            return .way
        case .polygon:
            return .way
        }
    }
}
