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
        locationManager.pausesLocationUpdatesAutomatically = false // Prevent auto-pausing
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func setLocation() {
        if let location = locationManager.location {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
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
    func getCalcLocation(depthValue: Float)
    -> (latitude: CLLocationDegrees, longitude: CLLocationDegrees)? {
        guard let latitude = self.latitude, let longitude = self.longitude, let heading = self.headingDegrees else {
            print("latitude, longitude, or heading: nil")
            return nil
        }

        // Calculate the object's coordinates assuming a flat plane
        let distance = depthValue
        let bearing = heading * .pi / 180.0 // Convert to radians

        // Calculate the change in coordinates
        let deltaX = Double(distance) * cos(Double(bearing))
        let deltaY = Double(distance) * sin(Double(bearing))

        // Assuming 1 degree of latitude and longitude is approximately 111,000 meters
        let metersPerDegree = 111_000.0

        let objectLatitude = latitude + (deltaY / metersPerDegree)
        let objectLongitude = longitude + (deltaX / metersPerDegree)

        return (latitude: CLLocationDegrees(objectLatitude),
                longitude: CLLocationDegrees(objectLongitude))
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
