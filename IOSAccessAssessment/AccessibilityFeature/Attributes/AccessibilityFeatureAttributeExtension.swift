//
//  AccessibilityFeatureAttribute.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation
import PointNMapShared

/**
    Enumeration defining various accessibility feature attributes, along with their metadata and value types.
 
    - Note: One needs to be aware of the value types associated with each attribute. The valueType property is only meant for reference.
 */
extension AccessibilityFeatureAttribute {
    /// TODO: Verify these OSM tag keys
    public var osmTagKey: String {
        switch self {
        case .width: return "width"
        case .runningSlope: return "incline"
        case .crossSlope: return "cross_slope"
        case .surfaceIntegrity: return "surface_integrity"
        case .lidarDepth: return APIConstants.TagKeys.lidarDepthKey
        case .latitudeDelta: return APIConstants.TagKeys.latitudeDeltaKey
        case .longitudeDelta: return APIConstants.TagKeys.longitudeDeltaKey
        case .widthLegacy: return "width_legacy"
        case .runningSlopeLegacy: return "incline_legacy"
        case .crossSlopeLegacy: return "cross_slope_legacy"
        case .widthFromImage: return "width_from_image"
        case .runningSlopeFromImage: return "running_slope_from_image"
        case .crossSlopeFromImage: return "cross_slope_from_image"
        default: return ""
        }
    }
}

