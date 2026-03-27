//
//  ContourUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Vision

struct ContourUtils {
    /**
     Function to compute the centroid, bounding box, and perimeter of a contour more efficiently
     
     TODO: Check if the performance can be improved by using SIMD operations
     */
    static func getCentroidAreaBounds(
        contour: VNContour
    ) -> (centroid: CGPoint, boundingBox: CGRect, perimeter: Float, area: Float) {
        let points = contour.normalizedPoints
        return getCentroidAreaBounds(normalizedPoints: points)
    }
    static func getCentroidAreaBounds(
        normalizedPoints points: [simd_float2]
    ) -> (centroid: CGPoint, boundingBox: CGRect, perimeter: Float, area: Float) {
        guard !points.isEmpty else { return (CGPoint.zero, .zero, 0, 0) }
        
        let centroidAreaResults = self.getCentroidAndArea(normalizedPoints: points)
        let boundingBox = self.getBoundingBox(normalizedPoints: points)
        let perimeter = self.getPerimeter(normalizedPoints: points)
        
        return (centroid: centroidAreaResults.centroid, boundingBox, perimeter, centroidAreaResults.area)
    }
    
    /**
     Use shoelace formula to calculate the area and centroid of the contour together.
     */
    static func getCentroidAndArea(contour: VNContour) -> (centroid: CGPoint, area: Float) {
        let points = contour.normalizedPoints
        return getCentroidAndArea(normalizedPoints: points)
    }
    static func getCentroidAndArea(normalizedPoints points: [simd_float2]) -> (centroid: CGPoint, area: Float) {
        guard !points.isEmpty else { return (CGPoint.zero, 0) }
        
        let count = points.count
        
        var area: Float = 0.0
        var cx: Float = 0.0
        var cy: Float = 0.0
        
        guard count > 2 else {
            cx = points.map { $0.x }.reduce(0, +) / Float(points.count)
            cy = points.map { $0.y }.reduce(0, +) / Float(points.count)
            let centroid = CGPoint(x: CGFloat(cx), y: CGFloat(cy))
            return (centroid, 0)
        }
        
        for i in 0..<count {
            let p0 = points[i]
            let p1 = points[(i + 1) % count] // wrap around to the first point
            
            let crossProduct = (p0.x * p1.y) - (p1.x * p0.y)
            area += crossProduct
            cx += (p0.x + p1.x) * crossProduct
            cy += (p0.y + p1.y) * crossProduct
        }
        
        area = 0.5 * area
        cx /= (6 * area)
        cy /= (6 * area)
        area = abs(area)
        guard area > 0 else { return (CGPoint.zero, 0) }
        
        let centroid = CGPoint(x: CGFloat(cx), y: CGFloat(cy))
        return (centroid, area)
    }
    
    static func getBoundingBox(contour: VNContour) -> CGRect {
        let points = contour.normalizedPoints
        return getBoundingBox(normalizedPoints: points)
    }
    static func getBoundingBox(normalizedPoints points: [simd_float2]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        
        for i in 0..<(points.count - 1) {
            minX = min(minX, points[i].x)
            minY = min(minY, points[i].y)
            maxX = max(maxX, points[i].x)
            maxY = max(maxY, points[i].y)
        }
        
        return CGRect(
            x: CGFloat(minX), y: CGFloat(minY),
            width: CGFloat(maxX - minX), height: CGFloat(maxY - minY)
        )
    }
    
    static func getPerimeter(contour: VNContour) -> Float {
        let points = contour.normalizedPoints
        return getPerimeter(normalizedPoints: points)
    }
    static func getPerimeter(normalizedPoints points: [simd_float2]) -> Float {
        guard !points.isEmpty else { return 0 }
        
        var perimeter: Float = 0.0
        let count = points.count
        
        for i in 0..<count {
            let p0 = points[i]
            let p1 = points[(i + 1) % count] // wrap around to the first point
            
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            perimeter += sqrt(dx*dx + dy*dy)
        }
        
        return perimeter
    }
}

/**
 NOTE: Methods that need to be replaced. 
 */
extension ContourUtils {
    /**
        Function to get the bounding box of the contour as a trapezoid. This is the largest trapezoid that can be contained in the contour and has horizontal lines.
        - Parameters:
            - points: The points of the contour
            - x_delta: The delta for the x-axis (minimum distance between points)
            - y_delta: The delta for the y-axis (minimum distance between points)
     */
    /**
     TODO: Check if the performance can be improved by using SIMD operations
     
     FIXME: This function suffers from an edge case
     Let's say the contour has a very small line at its lowest point, but just above it has a very wide line.
     In such a case, the function should probably return a trapezoid with the wider lower line,
     but it returns the trapezoid with the smaller line.
     We may have to come up with a better heuristic to determine the right shape for getting the way bounds.
     */
    static func getTrapezoid(contour: VNContour, x_delta: Float = 0.1, y_delta: Float = 0.1) -> [SIMD2<Float>]? {
        let points = contour.normalizedPoints
        return getTrapezoid(normalizedPoints: points, x_delta: x_delta, y_delta: y_delta)
    }
    static func getTrapezoid(
        normalizedPoints points: [simd_float2], x_delta: Float = 0.1, y_delta: Float = 0.1,
        isFlipped: Bool = false
    ) -> [SIMD2<Float>]? {
        guard !points.isEmpty else { return nil }
        var points = points
        if isFlipped {
            /// Flip x and y
            points = points.map { SIMD2<Float>($0.y, $0.x) }
        }
        let sortedByYPoints = points.sorted(by: { $0.y < $1.y })
        
        func intersectsAtY(p1: SIMD2<Float>, p2: SIMD2<Float>, y0: Float) -> SIMD2<Float>? {
            /// Check if y0 is between y1 and y2
            if (y0 - p1.y) * (y0 - p2.y) <= 0 && p1.y != p2.y {
                /// Linear interpolation to find x
                let t = (y0 - p1.y) / (p2.y - p1.y)
                let x = p1.x + t * (p2.x - p1.x)
                return SIMD2<Float>(x, y0)
            }
            return nil
        }
        
        var upperLeftX: Float? = nil
        var upperRightX: Float? = nil
        var lowerLeftX: Float? = nil
        var lowerRightX: Float? = nil
        
        /// Status flags
        var upperLineFound = false
        var lowerLineFound = false
        
        /// With two-pointer approach
        var lowY = 0
        var highY = points.count - 1
        while lowY < highY {
            if sortedByYPoints[lowY].y > (sortedByYPoints[highY].y - y_delta) {
                return nil
            }
            /// Check all the lines in the contour
            /// on whether they intersect with lowY or highY
            for i in 0..<points.count {
                let point1 = points[i]
                let point2 = points[(i + 1) % points.count]
                
                if (!lowerLineFound) {
                    let intersection1 = intersectsAtY(p1: point1, p2: point2, y0: sortedByYPoints[lowY].y)
                    if let intersection1 = intersection1 {
                        if (intersection1.x < (lowerLeftX ?? 2)) {
                            lowerLeftX = intersection1.x
                        }
                        if (intersection1.x > (lowerRightX ?? -1)) {
                            lowerRightX = intersection1.x
                        }
                    }
                }
                
                if (!upperLineFound) {
                    let intersection2 = intersectsAtY(p1: point1, p2: point2, y0: sortedByYPoints[highY].y)
                    if let intersection2 = intersection2 {
                        if (intersection2.x < (upperLeftX ?? 2)) {
                            upperLeftX = intersection2.x
                        }
                        if (intersection2.x > (upperRightX ?? -1)) {
                            upperRightX = intersection2.x
                        }
                    }
                }
            }
            if !lowerLineFound {
                if lowerLeftX != nil && lowerRightX != nil && (lowerLeftX! < lowerRightX! - x_delta) {
                    lowerLineFound = true
                } else {
                    lowerLeftX = nil
                    lowerRightX = nil
                }
            }
            if !upperLineFound {
                if upperLeftX != nil && upperRightX != nil && (upperLeftX! < upperRightX! - x_delta) {
                    upperLineFound = true
                } else {
                    upperLeftX = nil
                    upperRightX = nil
                }
            }
            if upperLineFound && lowerLineFound,
            let lowerLeftX = lowerLeftX, let lowerRightX = lowerRightX,
            let upperLeftX = upperLeftX, let upperRightX = upperRightX
            {
                let trapezoidPoints = [
                    SIMD2<Float>(lowerLeftX, sortedByYPoints[lowY].y),
                    SIMD2<Float>(upperLeftX, sortedByYPoints[highY].y),
                    SIMD2<Float>(upperRightX, sortedByYPoints[highY].y),
                    SIMD2<Float>(lowerRightX, sortedByYPoints[lowY].y)
                ]
                return isFlipped ? trapezoidPoints.map { SIMD2<Float>($0.y, $0.x) } : trapezoidPoints
            }
            
            if !lowerLineFound{
                lowY += 1
            }
            if !upperLineFound{
                highY -= 1
            }
        }
        
        return nil
    }
}
