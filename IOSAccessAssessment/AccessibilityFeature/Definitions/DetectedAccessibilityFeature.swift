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

/**
    A struct representing a detected accessibility feature in an image.
 
    TODO: Currently, thi struct only represents the contour details of the detected feature.
    Eventually, the goal is to generalize this struct to include all details that would be used to represent a detected accessibility feature.
    This may include a sub-mesh, depth information, etc.
 */
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
