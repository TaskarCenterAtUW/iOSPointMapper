//
//  ObjectLocation.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/04/29.
//

import SwiftUI
import UIKit
import AVFoundation
import CoreImage
import CoreLocation
import simd

class ObjectLocation: ObservableObject {
    var locationManager: CLLocationManager
    @Published var longitude: CLLocationDegrees?
    @Published var latitude: CLLocationDegrees?
    @Published var altitude: CLLocationDistance?
    @Published var headingDegrees: CLLocationDirection?
    
    let ciContext = CIContext(options: nil)
    
    init() {
        self.locationManager = CLLocationManager()
        self.longitude = nil
        self.latitude = nil
        self.headingDegrees = nil
        self.setupLocationManager()
    }
    
    private func setupLocationManager() {
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
    
    private func setLocation() {
        // FIXME: Ensure that the horizontal and vertical accuracy are acceptable
        // Else, do not update the location
        if let location = locationManager.location {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            self.altitude = location.altitude
        }
    }
    
    private func setHeading() {
        if let heading = locationManager.heading {
            self.headingDegrees = heading.magneticHeading
            //            headingStatus = "Heading: \(headingDegrees) degrees"
        }
    }
    
    func setLocationAndHeading() {
        setLocation()
        setHeading()
        
        guard let _ = self.latitude, let _ = self.longitude else {
            print("latitude or longitude: nil")
            return
        }
        
        guard let _ = self.headingDegrees else {
            print("heading: nil")
            return
        }
    }
}

extension ObjectLocation {
    /**
        Calculate the location of an object at a given depth value based on the current latitude, longitude, and heading.
        Uses the Great Circle Distance formula to approximate the object's coordinates.
     */
    func getCalcLocation(depthValue: Float)
    -> (latitude: CLLocationDegrees, longitude: CLLocationDegrees)? {
        guard let latitude = self.latitude, let longitude = self.longitude, let heading = self.headingDegrees else {
            print("latitude, longitude, or heading: nil")
            return nil
        }
        
        // FIXME: Use a more accurate radius for the Earth depending on the latitude
        let RADIUS = 6378137.0 // Earth's radius in meters (WGS 84)

        // Calculate the object's coordinates assuming a flat plane
        let distance = Double(depthValue)
        
        let lat1 = latitude * .pi / 180.0 // Convert to radians
        let lon1 = longitude * .pi / 180.0 // Convert to radians
        let bearing = heading * .pi / 180.0 // Convert to radians
        
        // FIXME: The following formula is the Great Circle Distance formula.
        // It makes the assumption that the Earth is a perfect sphere, which is not true.
        // Find a better formula that accounts for the Earth's ellipsoidal shape.
        let angularDistance = distance / RADIUS
        
        // NOTE: Have to break the two parts because of Swift compiler
        let objectLatitudeA = sin(lat1) * cos(angularDistance)
        let objectLatitudeB = cos(lat1) * sin(angularDistance) * cos(bearing)
        let objectLatitude = asin(objectLatitudeA + objectLatitudeB)
        
        let objectLongitudeA = sin(bearing) * sin(angularDistance) * cos(lat1)
        let objectLongitudeB = cos(angularDistance) - sin(lat1) * sin(objectLatitude)
        let objectLongitude = lon1 + atan2(objectLongitudeA, objectLongitudeB)
        
        let finalObjectLatitude = objectLatitude * 180.0 / .pi // Convert back to degrees
        let finalObjectLongitude = objectLongitude * 180.0 / .pi // Convert back to degrees

        return (latitude: CLLocationDegrees(finalObjectLatitude),
                longitude: CLLocationDegrees(finalObjectLongitude))
    }
    
    func getCalculation(pointWithDepth: SIMD3<Float>, imageSize: CGSize,
                        cameraTransform: simd_float4x4 = matrix_identity_float4x4,
                        cameraIntrinsics: simd_float3x3 = matrix_identity_float3x3)
    -> (latitude: CLLocationDegrees, longitude: CLLocationDegrees)? {
        guard let latitude = self.latitude, let longitude = self.longitude, let heading = self.headingDegrees else {
            print("latitude, longitude, or heading: nil")
            return nil
        }
        
        // Back-project the point from image coordinates to camera space
        let cameraInverseIntrinsics = simd_inverse(cameraIntrinsics)
        let pixel = simd_float3(Float(pointWithDepth.x), Float(pointWithDepth.y), 1.0)
        let ray = cameraInverseIntrinsics * pixel
        let rayDirection = simd_normalize(ray)
        
        // Scale the ray direction by the depth value to get the actual point in camera space
        let depth = Float(pointWithDepth.z)
        let localPoint = rayDirection * depth
        
        // Transform the point from camera space to world space
        let worldPoint4 = cameraTransform * simd_float4(localPoint, 1.0)
        let worldPoint = SIMD3<Float>(worldPoint4.x, worldPoint4.y, worldPoint4.z)
        
        // Get camera world coordinates
        let cameraPoint = simd_make_float3(cameraTransform.columns.3.x,
                                            cameraTransform.columns.3.y,
                                            cameraTransform.columns.3.z)
        let delta = worldPoint - cameraPoint
        
        let metersPerDegree: Float = 111_000.0
        
        let deltaLat = delta.z / metersPerDegree // Z = North
        
        let latRadians: Float = Float(latitude * .pi / 180.0)
        let deltaLon = delta.x / (metersPerDegree * cos(latRadians))
        
        let objectLatitude = latitude + CLLocationDegrees(deltaLat)
        let objectLongitude = longitude + CLLocationDegrees(deltaLon)
        
        return (latitude: objectLatitude,
                longitude: objectLongitude)
    }
    
    func getWayWidth(
        wayBoundsWithDepth: [SIMD3<Float>], imageSize: CGSize,
        cameraTransform: simd_float4x4 = matrix_identity_float4x4,
        cameraIntrinsics: simd_float3x3 = matrix_identity_float3x3
    ) -> Float {
        guard wayBoundsWithDepth.count == 4 else {
            print("Invalid way bounds")
            return 0.0
        }
        
        let fx = cameraIntrinsics.columns.0.x
        let fy = cameraIntrinsics.columns.1.y
        let cx = cameraIntrinsics.columns.2.x
        let cy = cameraIntrinsics.columns.2.y
        
        func imageToCameraSpace(x: Int, y: Int, z: Float) -> SIMD3<Float> {
            let X = (Float(x) - cx) * z / fx
            let Y = (Float(y) - cy) * z / fy
            let Z = z
            return SIMD3<Float>(X, Y, Z)
        }
        
        let wayPointsInCameraSpace = wayBoundsWithDepth.map { point in
            return imageToCameraSpace(x: Int(point.x), y: Int(point.y), z: point.z)
        }
        
        let lowerLeft = wayPointsInCameraSpace[0]
        let upperLeft = wayPointsInCameraSpace[1]
        let upperRight = wayPointsInCameraSpace[2]
        let lowerRight = wayPointsInCameraSpace[3]
        
        // Calculate the width in camera space
        let lowerWidth = simd_distance(lowerLeft, lowerRight)
        let upperWidth = simd_distance(upperLeft, upperRight)
        
        // Average the widths
        let widthInMeters = (lowerWidth + upperWidth) / 2.0
        
        return widthInMeters
    }
}
