//
//  DetectedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

struct ContourDetails: Sendable, Codable, Equatable, Hashable {
    let centroid: CGPoint
    /// Bounding box in the normalized coordinates.
    let boundingBox: CGRect
    let normalizedPoints: [SIMD2<Float>]
    let area: Float
    let perimeter: Float
    
    let trapezoidPoints: [SIMD2<Float>]?
    
    init(
        centroid: CGPoint, boundingBox: CGRect, normalizedPoints: [SIMD2<Float>], area: Float, perimeter: Float,
        trapezoidPoints: [SIMD2<Float>]? = nil
    ) {
        self.centroid = centroid
        self.boundingBox = boundingBox
        self.normalizedPoints = normalizedPoints
        self.area = area
        self.perimeter = perimeter
        self.trapezoidPoints = trapezoidPoints
    }
    
    init(normalizedPoints: [SIMD2<Float>], trapezoidPoints: [SIMD2<Float>]? = nil) {
        let contourDetails = ContourUtils.getCentroidAreaBounds(normalizedPoints: normalizedPoints)
        self.centroid = contourDetails.centroid
        self.boundingBox = contourDetails.boundingBox
        self.normalizedPoints = normalizedPoints
        self.area = contourDetails.area
        self.perimeter = contourDetails.perimeter
        self.trapezoidPoints = trapezoidPoints
    }
    
    init(contourDetails: ContourDetails, trapezoidPoints: [SIMD2<Float>]? = nil) {
        self.centroid = contourDetails.centroid
        self.boundingBox = contourDetails.boundingBox
        self.normalizedPoints = contourDetails.normalizedPoints
        self.area = contourDetails.area
        self.perimeter = contourDetails.perimeter
        self.trapezoidPoints = trapezoidPoints
    }
}

protocol DetectedFeatureProtocol: Equatable {
    var accessibilityFeatureClass: AccessibilityFeatureClass { get }
    var contourDetails: ContourDetails { get }
}

/**
    A struct representing a detected accessibility feature in an image.
 
    This AccessibilityFeature definition does not need to adhere to the AccessibilityFeatureProtocol, because it is relatively ephemeral in nature.
 
    TODO: Currently, this struct only represents the contour details of the detected feature.
    Eventually, the goal is to generalize this struct to include all details that would be used to represent a detected accessibility feature.
    This may include a sub-mesh, depth information, etc.
 */
struct DetectedAccessibilityFeature: Sendable, Equatable, Hashable, DetectedFeatureProtocol {
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
