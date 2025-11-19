//
//  DetectedObjectLegacy.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//


// TODO: DetectedObject was very quickly changed from struct to class
// Hence we need to test more thoroughly if this breaks anything.
class DetectedObject {
    let classLabel: UInt8
    
    var centroid: CGPoint
    var boundingBox: CGRect // Bounding box in the original image coordinates. In normalized coordinates.
    var normalizedPoints: [SIMD2<Float>]
    var area: Float
    var perimeter: Float
    
    var isCurrent: Bool // Indicates if the object is from the current frame or a previous frame
    var wayBounds: [SIMD2<Float>]? // Special property for way-type objects. In normalized coordinates.
    
    // MARK: Width Field Demo: Temporary properties for object width if it is a way-type object
    var calculatedWidth: Float? // Width of the object in meters
    var finalWidth: Float? // Final width of the object in meters after validation
    
    // MARK: Breakage Field Demo: Temporary properties for object breakage if it is a way-type object
    var calculatedBreakage: Bool? // Indicates if the object is broken or not
    var finalBreakage: Bool? // Final indication of breakage after validation
    
    // MARK: Slope Field Demo: Temporary properties for object slope if it is a way-type object
    var calculatedSlope: Float? // Slope of the object in degrees
    var finalSlope: Float? // Final slope of the object in degrees after validation
    
    // MARK: Cross-Slope Field Demo: Temporary properties for object cross-slope if it is a way-type object
    var calculatedCrossSlope: Float? // Cross-slope of the object in degrees
    var finalCrossSlope: Float? // Final cross-slope of the object in degrees after validation
    
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
