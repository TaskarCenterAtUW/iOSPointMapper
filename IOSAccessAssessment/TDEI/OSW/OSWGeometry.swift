//
//  OSWGeometry.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//

enum OSWGeometry: String, CaseIterable, Hashable {
    case point
    case linestring
    case polygon
    
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
}
