//
//  LocationHelpers.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/30/26.
//

import CoreLocation
import UIKit
import MapKit

public struct BBox {
    public let minLat: Double
    public let maxLat: Double
    public let minLon: Double
    public let maxLon: Double
    
    public init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.minLat = minLat
        self.maxLat = maxLat
        self.minLon = minLon
        self.maxLon = maxLon
    }
    
    public func toQueryString() -> String {
        return "\(minLon.roundedTo7Digits()),\(minLat.roundedTo7Digits()),\(maxLon.roundedTo7Digits()),\(maxLat.roundedTo7Digits())"
    }
}

public struct LocationHelpers {
    /**
    Calculates a bounding box around a given location with a specified radius. The bounding box is represented by its minimum and maximum latitude and longitude values.
     */
    public static func boundingBoxAroundLocation(location: CLLocationCoordinate2D, radius: CLLocationDistance) -> BBox {
        let region = MKCoordinateRegion(center: location, latitudinalMeters: radius, longitudinalMeters: radius)
        let center = region.center
        let span = region.span
        let minLat = center.latitude - span.latitudeDelta
        let maxLat = center.latitude + span.latitudeDelta
        let minLon = center.longitude - span.longitudeDelta
        let maxLon = center.longitude + span.longitudeDelta
        
        return BBox(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
    
    public struct MKDistanceHelpers {
        public static func distanceBetweenPoints(srcPoint: MKMapPoint, dstPoint: MKMapPoint) -> Double {
            return sqrt(pow(srcPoint.x - dstPoint.x, 2) + pow(srcPoint.y - dstPoint.y, 2))
        }
        
        /**
        Calculates the shortest distance from a point to a line segment defined by two endpoints. The distance is returned in the same units as the coordinates (e.g., meters if using map points).
         
         - Parameters:
            - srcPoint: The point from which the distance to the line segment is calculated.
            - lineStart: The starting point of the line segment.
            - lineEnd: The ending point of the line segment.
         
         - Procedure:
         If lineStart = A and lineEnd = B:
         Line Segment can be defined by L(t) = A + t(B - A), where t is a scalar in [0, 1].
         The distance from a point P to the line segment AB can be found by:
         1. Finding the projection of P onto the line defined by A and B, which gives us a point Q.
         2. If Q lies within the segment AB (i.e., t is between 0 and 1), then the distance from P to AB is the distance from P to Q.
         3. If Q does not lie within the segment AB, then the distance from P to AB is the minimum of the distances from P to A and P to B.
         */
        public static func distanceFromPointToLineSegment(
            srcPoint: MKMapPoint, lineStart: MKMapPoint, lineEnd: MKMapPoint
        ) -> Double? {
            let AP = MKMapPoint(x: srcPoint.x - lineStart.x, y: srcPoint.y - lineStart.y)
            let AB = MKMapPoint(x: lineEnd.x - lineStart.x, y: lineEnd.y - lineStart.y)
            let AB_length_squared = AB.x * AB.x + AB.y * AB.y
            guard AB_length_squared != 0 else {
                // lineStart and lineEnd are the same point, return distance from srcPoint to this point
                return sqrt(AP.x * AP.x + AP.y * AP.y)
            }
            let t = (AP.x * AB.x + AP.y * AB.y) / AB_length_squared
            
            if t > 0 && t <= 1 {
                // Projection falls on the line segment
                let projection = MKMapPoint(x: lineStart.x + t * AB.x, y: lineStart.y + t * AB.y)
                let distance = sqrt(pow(srcPoint.x - projection.x, 2) + pow(srcPoint.y - projection.y, 2))
                return distance
            } else {
                // Projection falls outside the line segment, return the minimum distance to the endpoints
                // Can check the value of t to determine which endpoint is closer, but this also works without that check.
                let distanceToStart = sqrt(pow(srcPoint.x - lineStart.x, 2) + pow(srcPoint.y - lineStart.y, 2))
                let distanceToEnd = sqrt(pow(srcPoint.x - lineEnd.x, 2) + pow(srcPoint.y - lineEnd.y, 2))
                return min(distanceToStart, distanceToEnd)
            }
        }
        
        public static func checkPointInsidePolygon(
            srcPoint: MKMapPoint, polygonPoints: [MKMapPoint]
        ) -> Bool {
            var insideCounter = 0
            var i = 0
            for j in 1...polygonPoints.count {
                let pi = polygonPoints[i % polygonPoints.count]
                let pj = polygonPoints[j % polygonPoints.count]
                if srcPoint.y > min(pi.y, pj.y) && srcPoint.y <= max(pi.y, pj.y) &&
                    srcPoint.x <= max(pi.x, pj.x) && pi.y != pj.y {
                    let xinters = (srcPoint.y - pi.y) * (pj.x - pi.x) / (pj.y - pi.y) + pi.x
                    if (pi.x == pj.x || srcPoint.x <= xinters) {
                        insideCounter += 1
                    }
                }
                i = j
            }
            return insideCounter % 2 != 0
        }
        
        /**
         Calculates the shortest distance from a point to a polygon defined by its vertices. The distance is returned in the same units as the coordinates (e.g., meters if using map points).
         
         - Parameters:
            - srcPoint: The point from which the distance to the polygon is calculated.
            - polygonPoints: An array of points representing the vertices of the polygon, ordered sequentially.
         
         - Procedure:
         1. First, check if the point is inside the polygon using a point-in-polygon test (e.g., ray-casting algorithm). If the point is inside, return distance 0.
         2. If the point is outside the polygon, iterate through each edge of the polygon (defined by consecutive vertices) and calculate the distance from the point to each edge using the distanceFromPointToLineSegment method. The minimum distance found across all edges is returned as the distance from the point to the polygon.
         */
        public static func distanceFromPointToPolygon(
            srcPoint: MKMapPoint, polygonPoints: [MKMapPoint]
        ) -> Double? {
            guard polygonPoints.count >= 3 else {
                // Not a valid polygon
                return nil
            }
            // Check if the point is inside the polygon using ray-casting algorithm
            let isInside = checkPointInsidePolygon(srcPoint: srcPoint, polygonPoints: polygonPoints)
            if isInside {
                return 0.0
            }
            var minDistance: Double = Double.infinity
            for i in 0..<polygonPoints.count {
                let lineStart = polygonPoints[i]
                let lineEnd = polygonPoints[(i + 1) % polygonPoints.count] // Wrap around to the first point
                if let distance = distanceFromPointToLineSegment(srcPoint: srcPoint, lineStart: lineStart, lineEnd: lineEnd) {
                    minDistance = min(minDistance, distance)
                }
            }
            return minDistance
        }
    }
}

