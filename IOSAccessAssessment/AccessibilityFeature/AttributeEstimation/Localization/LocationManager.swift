//
//  LocationManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import CoreLocation
import UIKit
import MapKit

struct BBox {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
    
    func toQueryString() -> String {
        return "\(minLon.roundedTo7Digits()),\(minLat.roundedTo7Digits()),\(maxLon.roundedTo7Digits()),\(maxLat.roundedTo7Digits())"
    }
}

struct LocationHelpers {
    /**
    Calculates a bounding box around a given location with a specified radius. The bounding box is represented by its minimum and maximum latitude and longitude values.
     */
    static func boundingBoxAroundLocation(location: CLLocationCoordinate2D, radius: CLLocationDistance) -> BBox {
        let region = MKCoordinateRegion(center: location, latitudinalMeters: radius, longitudinalMeters: radius)
        let center = region.center
        let span = region.span
        let minLat = center.latitude - span.latitudeDelta
        let maxLat = center.latitude + span.latitudeDelta
        let minLon = center.longitude - span.longitudeDelta
        let maxLon = center.longitude + span.longitudeDelta
        
        return BBox(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
    }
    
    struct MKDistanceHelpers {
        static func distanceBetweenPoints(srcPoint: MKMapPoint, dstPoint: MKMapPoint) -> Double {
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
        static func distanceFromPointToLineSegment(
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
        
        static func checkPointInsidePolygon(
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
        static func distanceFromPointToPolygon(
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
        
        static func distanceFromPolygonToPolygon(
            
        ) -> Double? {
            return 0.0
        }
    }
    
    /**
    Calculates the distance between two points represented by their location details. The distance is returned in meters.
     Unit of distance is determined by MapKit's MKMapPoint.
     */
    static func distanceBetweenPoints(
        srcLocationDetails: OSMLocationDetails, dstLocationDetails: OSMLocationDetails
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
    
//    static func distanceFromPointToLineString(
//        srcLocationDetails: OSMLocationDetails, dstLocationDetails: OSMLocationDetails
//    ) -> Double? {
//        guard let srcLocationElement = srcLocationDetails.locations.last,
//              srcLocationElement.isWay == false, srcLocationElement.isClosed == false,
//              let srcLocationCoordinate = srcLocationElement.coordinates.last,
//              let dstLocationElement = dstLocationDetails.locations.last,
//              dstLocationElement.isWay == true, dstLocationElement.isClosed == false else {
//            return nil
//        }
//        let srcLocation = CLLocation(latitude: srcLocationCoordinate.latitude, longitude: srcLocationCoordinate.longitude)
//        let srcMapPoint = MKMapPoint(srcLocationCoordinate)
//        let dstLocationCoordinates = dstLocationElement.coordinates
//        let dstLocations = dstLocationCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
//        let dstMapPoints: [MKMapPoint] = dstLocations.map { MKMapPoint($0) }
//        var minDistance: Double = Double.infinity
//        for i in 0..<(dstMapPoints.count - 1) {
//            let lineStart = dstMapPoints[i]
//    }
    
    /**
    Calculates the shortest distance between two linestrings represented by their location details.
     Unit of distance is determined by MapKit's MKMapPoint.
     
     - Note:
     Converts the coordinates of the linestrings into map points, then iterates through each line segment of the source linestring and calculates the distance from each point in the destination linestring to that line segment. The minimum distance found across all segments and points is returned as the distance between the two linestrings.
     */
    static func distanceBetweenLineStrings(
        srcLocationDetails: OSMLocationDetails, dstLocationDetails: OSMLocationDetails
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
        for i in 0..<(srcMapPoints.count - 1) {
            let lineStart = srcMapPoints[i]
            let lineEnd = srcMapPoints[i + 1]
            for dstPoint in dstMapPoints {
                if let distance = MKDistanceHelpers.distanceFromPointToLineSegment(
                    srcPoint: dstPoint, lineStart: lineStart, lineEnd: lineEnd
                ) {
                    minDistance = min(minDistance, distance)
                }
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
     */
    static func distanceBetweenPolygons(
        srcLocationDetails: OSMLocationDetails, dstLocationDetails: OSMLocationDetails
    ) -> Double? {
        let srcLocationCoordinateArrays = srcLocationDetails.locations
        let dstLocationCoordinateArrays = dstLocationDetails.locations
        guard srcLocationCoordinateArrays.count > 0, dstLocationCoordinateArrays.count > 0 else {
            return nil
        }
        
        var minDistance: Double = Double.infinity
        for srcLocationCoordinateArray in srcLocationCoordinateArrays {
            for dstLocationCoordinateArray in dstLocationCoordinateArrays {
                let srcOSMLocationDetails = OSMLocationDetails(locations: [srcLocationCoordinateArray])
                let dstOSMLocationDetails = OSMLocationDetails(locations: [dstLocationCoordinateArray])
                let srcGeometry: OSWGeometry = srcLocationCoordinateArray.isWay ? (
                    srcLocationCoordinateArray.isClosed ? .polygon : .linestring
                ) : .point
                let dstGeometry: OSWGeometry = dstLocationCoordinateArray.isWay ? (
                    dstLocationCoordinateArray.isClosed ? .polygon : .linestring
                ) : .point
                
                /// Must ensure the same units (in this case, decided by MKMapPoint)
                switch (srcGeometry, dstGeometry) {
                case (.point, .point):
                    guard let distance = distanceBetweenPoints(
                        srcLocationDetails: srcOSMLocationDetails, dstLocationDetails: dstOSMLocationDetails
                    ) else {
                        continue
                    }
                    minDistance = min(minDistance, distance)
                case (.point, .linestring):
                    guard let distance = distanceBetweenLineStrings(
                        srcLocationDetails: srcOSMLocationDetails, dstLocationDetails: dstOSMLocationDetails
                    ) else {
                        continue
                    }
                    continue
                case (.point, .polygon):
                    continue
                case (.linestring, .linestring):
                    continue
                case (.linestring, .polygon):
                    continue
                case (.polygon, .polygon):
                    continue
                default:
                    continue
                }
            }
        }
        return minDistance
    }
}


enum LocationManagerError: Error, LocalizedError {
    case locationUnavailable
    case headingUnavailable
    
    var errorDescription: String? {
        switch self {
        case .locationUnavailable:
            return "Location data is unavailable."
        case .headingUnavailable:
            return "Heading data is unavailable."
        }
    }
}

/**
 A wrapper around CLLocationManager to manage location and heading updates in a more controlled and safe manner.
 */
@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager: CLLocationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var currentHeading: CLHeading?
    
    override init() {
        super.init()
    }
    
    func startLocationUpdates() {
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        // TODO: Sync heading with the device orientation
        locationManager.headingOrientation = .portrait
        locationManager.headingFilter = kCLHeadingFilterNone
        
        locationManager.pausesLocationUpdatesAutomatically = false // Prevent auto-pausing
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    /**
    Updates the heading orientation of the location manager based on the current device orientation. This ensures that heading data is accurate and consistent with the user's perspective.
     */
    public func updateOrientation(_ orientation: UIInterfaceOrientation) {
        switch orientation {
        case .portrait:
            locationManager.headingOrientation = .portrait
        case .portraitUpsideDown:
            locationManager.headingOrientation = .portraitUpsideDown
        /// Flipped because the heading is relative to the device's top, which is opposite in landscape orientations
        case .landscapeLeft:
            locationManager.headingOrientation = .landscapeRight
        case .landscapeRight:
            locationManager.headingOrientation = .landscapeLeft
        default:
            locationManager.headingOrientation = .portrait
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        guard let horizontalAccuracy = latestLocation.horizontalAccuracy as CLLocationAccuracy?,
                let verticalAccuracy = latestLocation.verticalAccuracy as CLLocationAccuracy?,
              horizontalAccuracy > 0, verticalAccuracy > 0 else {
            return
        }
        Task { @MainActor in
            self.currentLocation = latestLocation
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard let headingAccuracy = newHeading.headingAccuracy as CLLocationDirection?,
              headingAccuracy > 0 else {
            return
        }
        Task { @MainActor in
            self.currentHeading = newHeading
        }
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
    }
}
