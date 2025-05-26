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
    
    // TODO: Get the actual device-specific attributes, instead of the hard-coded values
    func getWayWidth(wayBounds: [SIMD2<Float>], imageSize: CGSize) -> Float {
        guard wayBounds.count == 4 else {
            print("Invalid way bounds")
            return 0.0
        }
        
        func pixelCorToPixelWidth(v: Float, frameHeight: Float) -> Float {
            let a: Float = 23726.211
            let b: Float = -0.0232829
            let c: Float = 0.2012972
            var w = a * exp(b * v) + c
            w = w * 0.775862
            if w > 0 {
                return w
            }
            else {
                return 0.0
            }
        }
        
        let originalFrameWidth: Float = 1280 // 1920
        let originalFrameHeight: Float = 720 // 1080
        
        let frameWidth = Float(imageSize.width)
        let frameHeight = Float(imageSize.height)
        
        let lowY: Float = (1-wayBounds[0]).y*frameHeight
        let highY: Float = (1-wayBounds[1]).y*frameHeight
        
        let lowLeftX: Float = wayBounds[0].x*frameWidth
        let lowRightX: Float = wayBounds[3].x*frameWidth
        let highLeftX: Float = wayBounds[1].x*frameWidth
        let highRightX: Float = wayBounds[2].x*frameWidth
        
        let part1: Float = pixelCorToPixelWidth(
            v: lowY*originalFrameHeight/frameHeight, frameHeight: frameHeight
        )*(lowRightX-lowLeftX)*originalFrameWidth/frameWidth
        let part2: Float = pixelCorToPixelWidth(
            v: highY*originalFrameHeight/frameHeight, frameHeight: frameHeight
        )*(highRightX-highLeftX)*originalFrameWidth/frameWidth

        let hardware_width_scale: Float = 0.775862
        var widthInMeters: Float = 1/2*(part1 + part2) * 0.0254
        widthInMeters *= hardware_width_scale
        
        return widthInMeters
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
