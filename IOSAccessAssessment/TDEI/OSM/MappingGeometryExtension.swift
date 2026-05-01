//
//  MappingGeometryExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//
import PointNMapShared

extension MappingGeometry {
    var osmElementType: OSMElementType {
        switch self {
        case .point:
            return .node
        case .linestring:
            return .way
        case .polygon:
            return .way
        default:
            return .node
        }
    }
}
