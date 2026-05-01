//
//  AccessibilityFeatureKind.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/26.
//

/**
 AccessibilityFeatureKind refers to the semantic type of the feature that you would find in an environment where the feature is being captured.
 */
public enum AccessibilityFeatureKind: String, Identifiable, Codable, CaseIterable, Equatable, Sendable {
    case sidewalk = "sidewalk"
    case building = "building"
    case pole = "pole"
    case trafficLight = "traffic_light"
    case trafficSign = "traffic_sign"
    case vegetation = "vegetation"
    
    public var id: String {
        return self.rawValue
    }
}
