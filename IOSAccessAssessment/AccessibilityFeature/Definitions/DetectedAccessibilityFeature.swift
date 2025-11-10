//
//  DetectedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

struct ContourDetails: Sendable, Codable, Equatable, Hashable {
    let centroid: CGPoint
    let boundingBox: CGRect // Bounding box in the original image coordinates. In normalized coordinates.
    let normalizedPoints: [SIMD2<Float>]
    let area: Float
    let perimeter: Float
}

struct DetectedAccessibilityFeature: Sendable, Equatable, Hashable {
    let accessibilityFeatureClass: AccessibilityFeatureClass
    let contourDetails: ContourDetails
    
    init(
        accessibilityFeatureClass: AccessibilityFeatureClass,
        contourDetails: ContourDetails
    ) {
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.contourDetails = contourDetails
    }
}
