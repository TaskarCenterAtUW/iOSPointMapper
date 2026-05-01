//
//  AccessibilityFeatureKindExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/26.
//

import PointNMapShared

extension AccessibilityFeatureKind {
    var oswPolicy: OSWPolicy {
        switch self {
        case .sidewalk: return OSWPolicy(oswElementClass: .Sidewalk, isExistingFirst: true)
        case .building: return OSWPolicy(oswElementClass: .Building, isExistingFirst: false)
        case .pole: return OSWPolicy(oswElementClass: .Pole, isExistingFirst: false)
        case .trafficLight: return OSWPolicy(oswElementClass: .TrafficLight, isExistingFirst: false)
        case .trafficSign: return OSWPolicy(oswElementClass: .TrafficSign, isExistingFirst: false)
        case .vegetation: return OSWPolicy(oswElementClass: .Vegetation, isExistingFirst: false)
        default: return OSWPolicy.default
        }
    }
}
