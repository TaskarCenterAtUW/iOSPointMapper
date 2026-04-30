//
//  LocationHelpers.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/30/26.
//

import CoreLocation
import UIKit
import MapKit
import PointNMapShared

public extension LocationHelpers {
    /**
     Calculates the distance between two locations represented by their location details if they have similar geometry types.
     Not commutative, checks distance from source to destination, so the order of the parameters matters.
     Unit of distance is determined by MapKit's MKMapPoint.
     
     - Note:
     First, checks the geometry types of the source and destination location details (e.g., point, linestring, polygon) based on the properties of their last location element. Then, based on the geometry types, it calls the appropriate distance calculation method (e.g., distanceBetweenPoints, distanceFromPointToLineString, distanceFromPointToPolygon, distanceBetweenLineStrings, distanceFromLineStringToPolygon, distanceBetweenPolygons) to compute the distance between the two locations.
     */
    static func distanceBetweenSimilarOSMLocationDetails(
        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
    ) -> Double? {
        guard let srcLastLocationElement = srcLocationDetails.locations.last else {
            return nil
        }
//        let isSrcMultipolygon = srcLocationDetails.locations.count > 1
        let isSrcPolygon = srcLastLocationElement.isWay && srcLastLocationElement.isClosed // && (!isSrcMultipolygon)
        let isSrcLineString = srcLastLocationElement.isWay && !srcLastLocationElement.isClosed // && (!isSrcMultipolygon)
        let isSrcPoint = !srcLastLocationElement.isWay && !srcLastLocationElement.isClosed // && (!isSrcMultipolygon)
        
        guard let dstLastLocationElement = dstLocationDetails.locations.last else {
            return nil
        }
//        let isDstMultipolygon = dstLocationDetails.locations.count > 1
        let isDstPolygon = dstLastLocationElement.isWay && dstLastLocationElement.isClosed // && (!isDstMultipolygon)
        let isDstLineString = dstLastLocationElement.isWay && !dstLastLocationElement.isClosed // && (!isDstMultipolygon)
        let isDstPoint = !dstLastLocationElement.isWay && !dstLastLocationElement.isClosed // && (!isDstMultipolygon)
        
        if isSrcPoint && isDstPoint {
            return distanceBetweenPoints(srcLocationDetails: srcLocationDetails, dstLocationDetails: dstLocationDetails)
        } else if isSrcLineString && isDstLineString {
            return distanceBetweenLineStrings(srcLocationDetails: srcLocationDetails, dstLocationDetails: dstLocationDetails)
        } else if isSrcPolygon && isDstPolygon {
            return distanceBetweenPolygons(srcLocationDetails: srcLocationDetails, dstLocationDetails: dstLocationDetails)
        } else {
            return nil
        }
    }
    
    /**
    Calculates the distance between two points represented by their location details. The distance is returned in meters.
     Unit of distance is determined by MapKit's MKMapPoint.
     */
    static func distanceBetweenPoints(
        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
    ) -> Double? {
        guard let srcLocationElement = srcLocationDetails.locations.last,
              srcLocationElement.isWay == false, srcLocationElement.isClosed == false,
              let srcLocationCoordinate = srcLocationElement.coordinates.last,
              let dstLocationElement = dstLocationDetails.locations.last,
              dstLocationElement.isWay == false, dstLocationElement.isClosed == false,
              let dstLocationCoordinate = dstLocationElement.coordinates.last else {
            return nil
        }
        let srcLocation = CLLocation(latitude: srcLocationCoordinate.latitude, longitude: srcLocationCoordinate.longitude)
        let dstLocation = CLLocation(latitude: dstLocationCoordinate.latitude, longitude: dstLocationCoordinate.longitude)
        return MKDistanceHelpers.distanceBetweenPoints(srcPoint: MKMapPoint(srcLocationCoordinate), dstPoint: MKMapPoint(dstLocationCoordinate))
    }
    
    /**
    Calculates the shortest distance from a point to a linestring represented by their location details.
     Unit of distance is determined by MapKit's MKMapPoint.
     
        - Note:
        Converts the coordinates of the linestring into map points, then iterates through each line segment of the linestring and calculates the distance from the point to that line segment using the distanceFromPointToLineSegment method. The minimum distance found across all segments is returned as the distance from the point to the linestring.
     */
    static func distanceFromPointToLineString(
        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
    ) -> Double? {
        guard let srcLocationElement = srcLocationDetails.locations.last,
              srcLocationElement.isWay == false, srcLocationElement.isClosed == false,
              let srcLocationCoordinate = srcLocationElement.coordinates.last,
              let dstLocationElement = dstLocationDetails.locations.last,
              dstLocationElement.isWay == true, dstLocationElement.isClosed == false else {
            return nil
        }
        let srcLocation = CLLocation(latitude: srcLocationCoordinate.latitude, longitude: srcLocationCoordinate.longitude)
        let srcMapPoint = MKMapPoint(srcLocationCoordinate)
        let dstLocationCoordinates = dstLocationElement.coordinates
        let dstLocations = dstLocationCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let dstMapPoints: [MKMapPoint] = dstLocations.map { MKMapPoint($0) }
        var minDistance: Double = Double.infinity
        for i in 0..<(dstMapPoints.count - 1) {
            let lineStart = dstMapPoints[i]
            let lineEnd = dstMapPoints[i + 1]
            if let distance = MKDistanceHelpers.distanceFromPointToLineSegment(
                srcPoint: srcMapPoint, lineStart: lineStart, lineEnd: lineEnd
            ) {
                minDistance = min(minDistance, distance)
            }
        }
        return minDistance
    }
    
    /**
    Calculates the shortest distance from a point to a polygon (single polygon) represented by their location details.
     Unit of distance is determined by MapKit's MKMapPoint.
     
        - Note:
        Converts the coordinates of the polygon into map points, then iterates through each edge of the polygon and calculates the distance from the point to that edge using the distanceFromPointToLineSegment method. The minimum distance found across all edges is returned as the distance from the point to the polygon. If the point is inside the polygon, the distance returned is 0.
     */
    static func distanceFromPointToPolygon(
        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
    ) -> Double? {
        guard let srcLocationElement = srcLocationDetails.locations.last,
              srcLocationElement.isWay == false, srcLocationElement.isClosed == false,
              let srcLocationCoordinate = srcLocationElement.coordinates.last,
              let dstLocationElement = dstLocationDetails.locations.last,
              dstLocationElement.isWay == true, dstLocationElement.isClosed == true else {
            return nil
        }
        let srcLocation = CLLocation(latitude: srcLocationCoordinate.latitude, longitude: srcLocationCoordinate.longitude)
        let srcMapPoint = MKMapPoint(srcLocationCoordinate)
        let dstLocationCoordinates = dstLocationElement.coordinates
        let dstLocations = dstLocationCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let dstMapPoints: [MKMapPoint] = dstLocations.map { MKMapPoint($0) }
        return MKDistanceHelpers.distanceFromPointToPolygon(srcPoint: srcMapPoint, polygonPoints: dstMapPoints)
    }
    
//    static func distanceFromPointToMultiPolygon(
//        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
//    ) -> Double? {
//        var minDistance: Double = Double.infinity
//        dstLocationDetails.locations.forEach { locationElement in
//            guard locationElement.isWay == true, locationElement.isClosed == true else {
//                return
//            }
//            let singlePolygonLocationDetails = LocationDetails(locations: [locationElement])
//            if let distance = distanceFromPointToPolygon(srcLocationDetails: srcLocationDetails, dstLocationDetails: singlePolygonLocationDetails) {
//                minDistance = min(minDistance, distance)
//            }
//        }
//        return minDistance
//    }
    
    /**
    Calculates the shortest distance between two linestrings represented by their location details.
     Unit of distance is determined by MapKit's MKMapPoint.
     
     - Note:
     Converts the coordinates of the linestrings into map points, then iterates through each line segment of the dst linestring and calculates the distance from each point in the source linestring to that line segment. The minimum distance found across all segments and points is returned as the distance between the two linestrings.
     
     - Warning:
        The logic for overlapping linestring needs to be updated, so that it captures the degree of overlap instead of just returning 0. This is because in some cases, two linestrings may partially overlap with each other, and the distance should reflect how much of the linestrings are outside of each other rather than just indicating that there is some overlap.
     */
    static func distanceBetweenLineStrings(
        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
    ) -> Double? {
        guard let srcLocationElement = srcLocationDetails.locations.last,
              srcLocationElement.isWay == true, srcLocationElement.isClosed == false,
              let dstLocationElement = dstLocationDetails.locations.last,
              dstLocationElement.isWay == true, dstLocationElement.isClosed == false else {
            return nil
        }
        let srcLocationCoordinates = srcLocationElement.coordinates
        let srcLocations = srcLocationCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let srcMapPoints: [MKMapPoint] = srcLocations.map { MKMapPoint($0) }
        let dstLocationCoordinates = dstLocationElement.coordinates
        let dstLocations = dstLocationCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let dstMapPoints: [MKMapPoint] = dstLocations.map { MKMapPoint($0) }
        
        var minDistance: Double = Double.infinity
        for i in 0..<(dstMapPoints.count - 1) {
            let lineStart = dstMapPoints[i]
            let lineEnd = dstMapPoints[i + 1]
            for srcPoint in srcMapPoints {
                if let distance = MKDistanceHelpers.distanceFromPointToLineSegment(
                    srcPoint: srcPoint, lineStart: lineStart, lineEnd: lineEnd
                ) {
                    minDistance = min(minDistance, distance)
                }
            }
        }
        return minDistance
    }
    
    /**
    Calculates the shortest distance from a linestring to a polygon (single polygon) represented by their location details.
        Unit of distance is determined by MapKit's MKMapPoint.
     
     - Note:
     Converts the coordinates of the linestring and polygon into map points, then iterates through each edge of the polygon and calculates the distance from each point in the linestring to that edge using the distanceFromPointToLineSegment method. The minimum distance found across all edges and points is returned as the distance from the linestring to the polygon. If any point of the linestring is inside the polygon, the distance returned is 0.
     
     - Warning:
     The logic for overlapping linestring needs to be updated, so that it captures the degree of overlap instead of just returning 0. This is because in some cases, a linestring may partially overlap with a polygon, and the distance should reflect how much of the linestring is outside the polygon rather than just indicating that there is some overlap.
     */
    static func distanceFromLineStringToPolygon(
        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
    ) -> Double? {
        guard let srcLocationElement = srcLocationDetails.locations.last,
              srcLocationElement.isWay == true, srcLocationElement.isClosed == false,
              let dstLocationElement = dstLocationDetails.locations.last,
              dstLocationElement.isWay == true, dstLocationElement.isClosed == true else {
            return nil
        }
        let srcLocationCoordinates = srcLocationElement.coordinates
        let srcLocations = srcLocationCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let srcMapPoints: [MKMapPoint] = srcLocations.map { MKMapPoint($0) }
        let dstLocationCoordinates = dstLocationElement.coordinates
        let dstLocations = dstLocationCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let dstMapPoints: [MKMapPoint] = dstLocations.map { MKMapPoint($0) }
        
        var minDistance: Double = Double.infinity
        for i in 0..<(dstMapPoints.count - 1) {
            let lineStart = dstMapPoints[i]
            let lineEnd = dstMapPoints[i + 1]
            for srcPoint in srcMapPoints {
                if let distance = MKDistanceHelpers.distanceFromPointToLineSegment(
                    srcPoint: srcPoint, lineStart: lineStart, lineEnd: lineEnd
                ) {
                    minDistance = min(minDistance, distance)
                }
            }
        }
        return minDistance
    }
    
//    static func distanceFromLineStringToMultiPolygon(
//        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
//    ) -> Double? {
//        var minDistance: Double = Double.infinity
//        dstLocationDetails.locations.forEach { locationElement in
//            guard locationElement.isWay == true, locationElement.isClosed == true else {
//                return
//            }
//            let singlePolygonLocationDetails = LocationDetails(locations: [locationElement])
//            if let distance = distanceFromLineStringToPolygon(srcLocationDetails: srcLocationDetails, dstLocationDetails: singlePolygonLocationDetails) {
//                minDistance = min(minDistance, distance)
//            }
//        }
//        return minDistance
//    }
    
    /**
    Calculates the shortest distance between two polygons (single polygons) represented by their location details.
        Unit of distance is determined by MapKit's MKMapPoint.
     
    - Note:
    Converts the coordinates of the polygons into map points, then iterates through each edge of the first polygon and calculates the distance from each point in the second polygon to that edge using the distanceFromPointToLineSegment method. The minimum distance found across all edges and points is returned as the distance between the two polygons. If any point of one polygon is inside the other polygon, the distance returned is 0.
     
     - Warning:
        The logic for overlapping polygons needs to be updated, so that it captures the degree of overlap instead of just returning 0. This is because in some cases, two polygons may partially overlap with each other, and the distance should reflect how much of the polygons are outside of each other rather than just indicating that there is some overlap.
     */
    static func distanceBetweenPolygons(
        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
    ) -> Double? {
        guard let srcLocationElement = srcLocationDetails.locations.last,
              srcLocationElement.isWay == true, srcLocationElement.isClosed == true,
              let dstLocationElement = dstLocationDetails.locations.last,
              dstLocationElement.isWay == true, dstLocationElement.isClosed == true else {
            return nil
        }
        let srcLocationCoordinates = srcLocationElement.coordinates
        let srcLocations = srcLocationCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let srcMapPoints: [MKMapPoint] = srcLocations.map { MKMapPoint($0) }
        let dstLocationCoordinates = dstLocationElement.coordinates
        let dstLocations = dstLocationCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        let dstMapPoints: [MKMapPoint] = dstLocations.map { MKMapPoint($0) }
        
        var minDistance: Double = Double.infinity
        for srcPoint in srcMapPoints {
            if let distance = MKDistanceHelpers.distanceFromPointToPolygon(srcPoint: srcPoint, polygonPoints: dstMapPoints) {
                minDistance = min(minDistance, distance)
            }
        }
        return minDistance
    }
    
    /**
    Calculates the shortest distance between two polygons represented by their location details.
     Can have negative distance if there is polygon overlap, where the absolute value of negative distances represents the degree of overlap.
     Unit of distance is determined by MapKit's MKMapPoint.
     
     - Note:
     Converts the coordinates of the polygons into map points, then iterates through each edge of the source polygon and calculates the distance from each point in the destination polygon to that edge using the distanceFromPointToLineSegment method. The minimum distance found across all edges and points is returned as the distance between the two polygons.
     
     - Warning:
        The logic for overlapping polygons needs to be updated, so that it captures the degree of overlap instead of just returning 0. This is because in some cases, two polygons may partially overlap with each other, and the distance should reflect how much of the polygons are outside of each other rather than just indicating that there is some overlap.
     
     - Warning:
     Currently, this algorithm doesn't actually consider the relation role of each multi-polygon member (e.g. outer vs inner), which can lead to inaccurate distance calculations in some cases. For example, if one of the multi-polygons has an inner member that overlaps with the other multi-polygon, the distance should be negative to reflect the degree of overlap. However, without considering the relation type, the algorithm may simply return a distance of 0 for this case, which does not accurately capture the spatial relationship between the two multi-polygons.
     */
//    static func distanceBetweenMultiPolygons(
//        srcLocationDetails: LocationDetails, dstLocationDetails: LocationDetails
//    ) -> Double? {
//        let srcLocationCoordinateArrays = srcLocationDetails.locations
//        let dstLocationCoordinateArrays = dstLocationDetails.locations
//        guard srcLocationCoordinateArrays.count > 0, dstLocationCoordinateArrays.count > 0 else {
//            return nil
//        }
//        
//        var minDistance: Double = Double.infinity
//        for srcLocationCoordinateArray in srcLocationCoordinateArrays {
//            for dstLocationCoordinateArray in dstLocationCoordinateArrays {
//                let srcOSMLocationDetails = LocationDetails(locations: [srcLocationCoordinateArray])
//                let dstOSMLocationDetails = LocationDetails(locations: [dstLocationCoordinateArray])
//                /// While deciding the geometry, we are not using the .polygon enumeration, since that actually represents a multipolygon in OSW.
//                let srcGeometry: OSWGeometry = srcLocationCoordinateArray.isWay ? .linestring : .point
//                let isSrcPolygon = srcLocationCoordinateArray.isWay && srcLocationCoordinateArray.isClosed
//                let dstGeometry: OSWGeometry = dstLocationCoordinateArray.isWay ? .linestring : .point
//                let isDstPolygon = dstLocationCoordinateArray.isWay && dstLocationCoordinateArray.isClosed
//                
//                /// Must ensure the same units (in this case, decided by MKMapPoint)
//                if (srcGeometry == .point && dstGeometry == .point) {
//                    guard let distance = distanceBetweenPoints(
//                        srcLocationDetails: srcOSMLocationDetails, dstLocationDetails: dstOSMLocationDetails
//                    ) else {
//                        continue
//                    }
//                    minDistance = min(minDistance, distance)
//                }
//                else if (srcGeometry == .point && (dstGeometry == .linestring && !isDstPolygon)) {
//                    guard let distance = distanceFromPointToLineString(
//                        srcLocationDetails: srcOSMLocationDetails, dstLocationDetails: dstOSMLocationDetails
//                    ) else {
//                        continue
//                    }
//                    minDistance = min(minDistance, distance)
//                }
//                else if (srcGeometry == .point && (dstGeometry == .linestring && isDstPolygon)) {
//                    guard let distance = distanceFromPointToPolygon(
//                        srcLocationDetails: srcOSMLocationDetails, dstLocationDetails: dstOSMLocationDetails
//                    ) else {
//                        continue
//                    }
//                    minDistance = min(minDistance, distance)
//                }
//                else if ((srcGeometry == .linestring && !isSrcPolygon) && (dstGeometry == .linestring && !isDstPolygon)) {
//                    guard let distance = distanceBetweenLineStrings(
//                        srcLocationDetails: srcOSMLocationDetails, dstLocationDetails: dstOSMLocationDetails
//                    ) else {
//                        continue
//                    }
//                    minDistance = min(minDistance, distance)
//                }
//                else if ((srcGeometry == .linestring && !isSrcPolygon) && (dstGeometry == .linestring && isDstPolygon)) {
//                    guard let distance = distanceFromLineStringToPolygon(
//                        srcLocationDetails: srcOSMLocationDetails, dstLocationDetails: dstOSMLocationDetails
//                    ) else {
//                        continue
//                    }
//                    minDistance = min(minDistance, distance)
//                }
//                else if ((srcGeometry == .linestring && isSrcPolygon) && (dstGeometry == .linestring && isDstPolygon)) {
//                    guard let distance = distanceBetweenPolygons(
//                        srcLocationDetails: srcOSMLocationDetails, dstLocationDetails: dstOSMLocationDetails
//                    ) else {
//                        continue
//                    }
//                }
//                else {
//                    continue
//                }
//            }
//        }
//        return minDistance
//    }
}

