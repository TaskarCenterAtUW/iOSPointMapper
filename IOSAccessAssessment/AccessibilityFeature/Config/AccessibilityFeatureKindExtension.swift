//
//  AccessibilityFeatureKindExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/26.
//

import PointNMapShared

/**
 Extension to add mapping-related logic to AccessibilityFeatureKind.
 */
extension AccessibilityFeatureKind {
    var oswPolicy: OSWPolicy {
        switch self {
        case .sidewalk: return OSWPolicy(oswElementClass: .Sidewalk, isExistingFirst: true)
        case .building: return OSWPolicy(oswElementClass: .Building, isExistingFirst: true)
        case .pole: return OSWPolicy(oswElementClass: .Pole, isExistingFirst: true)
        case .trafficLight: return OSWPolicy(oswElementClass: .TrafficLight, isExistingFirst: true)
        case .trafficSign: return OSWPolicy(oswElementClass: .TrafficSign, isExistingFirst: true)
        case .vegetation: return OSWPolicy(oswElementClass: .Vegetation, isExistingFirst: true)
        case .curbRamp: return OSWPolicy(oswElementClass: .CurbRamp, isExistingFirst: true)
        default: return OSWPolicy.default
        }
    }
    
    var ambiguityCasePolicy: AmbiguityCasePolicy {
        switch self {
        case .sidewalk:
            return AmbiguityCasePolicy.default
        case .building:
            return AmbiguityCasePolicy.default
        case .pole:
            return AmbiguityCasePolicy.default
        case .trafficLight:
            return AmbiguityCasePolicy.default
        case .trafficSign:
            return AmbiguityCasePolicy.default
        case .curbRamp:
            return AmbiguityCasePolicy.default
        default: return AmbiguityCasePolicy.default
        }
    }
}
