//
//  DetectedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//
import CoreGraphics

public struct ContourDetails: Sendable, Codable, Equatable, Hashable {
    public let centroid: CGPoint
    /// Bounding box in the normalized coordinates.
    public let boundingBox: CGRect
    public let normalizedPoints: [SIMD2<Float>]
    public let area: Float
    public let perimeter: Float
    
    /// Specialized property to hold the 4 points of the trapezoid that approximates the contour, if applicable.
    public let trapezoidPoints: [SIMD2<Float>]?
    
    public init(
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
    
    public init(normalizedPoints: [SIMD2<Float>], trapezoidPoints: [SIMD2<Float>]? = nil) {
        let contourDetails = ContourUtils.getCentroidAreaBounds(normalizedPoints: normalizedPoints)
        self.centroid = contourDetails.centroid
        self.boundingBox = contourDetails.boundingBox
        self.normalizedPoints = normalizedPoints
        self.area = contourDetails.area
        self.perimeter = contourDetails.perimeter
        self.trapezoidPoints = trapezoidPoints
    }
    
    public init(contourDetails: ContourDetails, trapezoidPoints: [SIMD2<Float>]? = nil) {
        self.centroid = contourDetails.centroid
        self.boundingBox = contourDetails.boundingBox
        self.normalizedPoints = contourDetails.normalizedPoints
        self.area = contourDetails.area
        self.perimeter = contourDetails.perimeter
        self.trapezoidPoints = trapezoidPoints
    }
}

public protocol DetectedFeatureProtocol: Equatable {
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
public struct DetectedAccessibilityFeature: Sendable, Equatable, Hashable, DetectedFeatureProtocol {
    public let accessibilityFeatureClass: AccessibilityFeatureClass
    public let contourDetails: ContourDetails
    
    public init(
        accessibilityFeatureClass: AccessibilityFeatureClass,
        contourDetails: ContourDetails
    ) {
        self.accessibilityFeatureClass = accessibilityFeatureClass
        self.contourDetails = contourDetails
    }
}
