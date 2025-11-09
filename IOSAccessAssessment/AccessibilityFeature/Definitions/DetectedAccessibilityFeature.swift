//
//  DetectedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

struct DetectedAccessibilityFeature {
    struct WayProperties {
        var bounds: [SIMD2<Float>]
        
        var width: Float
        var breakage: Bool
        var slope: Float
        var crossSlope: Float
    }
    
    struct DebugProperties {
        var calculatedWidth: Float?
        var calculatedBreakage: Bool?
        var calculatedSlope: Float?
        var calculatedCrossSlope: Float?
    }
    
    let classLabel: UInt8
    
    // Contour properties
    var centroid: CGPoint
    var boundingBox: CGRect // Bounding box in the original image coordinates. In normalized coordinates.
    var normalizedPoints: [SIMD2<Float>]
    var area: Float
    var perimeter: Float
    
    var isCurrent: Bool // Indicates if the object is from the current frame or a previous frame
    var wayBounds: [SIMD2<Float>]? // Special property for way-type objects. In normalized coordinates.
    
    init(classLabel: UInt8, centroid: CGPoint, boundingBox: CGRect, normalizedPoints: [SIMD2<Float>], area: Float, perimeter: Float, isCurrent: Bool, wayBounds: [SIMD2<Float>]? = nil) {
        self.classLabel = classLabel
        self.centroid = centroid
        self.boundingBox = boundingBox
        self.normalizedPoints = normalizedPoints
        self.area = area
        self.perimeter = perimeter
        self.isCurrent = isCurrent
        self.wayBounds = wayBounds
    }
}
