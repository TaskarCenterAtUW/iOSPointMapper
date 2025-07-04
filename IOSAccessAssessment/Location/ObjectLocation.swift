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
            self.headingDegrees = heading.trueHeading
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
    
    func getLocationAndHeading() -> (latitude: CLLocationDegrees?, longitude: CLLocationDegrees?, heading: CLLocationDirection?) {
        return (latitude: self.latitude, longitude: self.longitude, heading: self.headingDegrees)
    }
}

extension ObjectLocation {
    /**
        Calculate the location of an object at a given point with depth in the image.
        Uses the camera intrinsics and transform to convert the image coordinates to world coordinates.
        
        Assumes that ARKit has the world alignment set to `ARWorldAlignment.gravityAndHeading`.
     */
    func getCalcLocation(pointWithDepth: SIMD3<Float>, imageSize: CGSize,
                        cameraTransform: simd_float4x4 = matrix_identity_float4x4,
                        cameraIntrinsics: simd_float3x3 = matrix_identity_float3x3,
                        deviceOrientation: UIDeviceOrientation = .landscapeLeft,
                        originalImageSize: CGSize
    )
    -> (latitude: CLLocationDegrees, longitude: CLLocationDegrees)? {
        let delta = getDeltaFromPoint(
            pointWithDepth: pointWithDepth, imageSize: imageSize,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics,
            deviceOrientation: deviceOrientation, originalImageSize: originalImageSize)
        
        return getCalcLocation(deltaLat: delta.z, deltaLon: delta.x)
    }
    
    /**
        Calculate the location of an object at a given depth value based on the current latitude, longitude, and heading.
        Uses the Great Circle Distance formula to approximate the object's coordinates.
     */
    func getCalcLocation(depthValue: Float)
    -> (latitude: CLLocationDegrees, longitude: CLLocationDegrees)? {
        guard
            let latitude = self.latitude, let longitude = self.longitude,
                let heading = self.headingDegrees else {
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
    
    /**
     Calculate the location of an object at a given delta latitude and longitude.
     Uses the Great Circle Distance formula to approximate the object's coordinates.
     */
    func getCalcLocation(deltaLat: Float, deltaLon: Float) -> (latitude: CLLocationDegrees, longitude: CLLocationDegrees)? {
        guard
            let latitude = self.latitude, let longitude = self.longitude
        else {
            print("latitude, longitude, or heading: nil")
            return nil
        }
        
        // FIXME: Use a more accurate radius for the Earth depending on the latitude
        let RADIUS = 6378137.0 // Earth's radius in meters (WGS 84)
        
        // Calculate distance and bearing
        let distance = Double(sqrt(deltaLat * deltaLat + deltaLon * deltaLon))
        let bearing = Double(atan2(deltaLon, deltaLat))
        
        let lat1 = latitude * .pi / 180.0 // Convert to radians
        let lon1 = longitude * .pi / 180.0 // Convert to radians
        
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
    
    func getWayWidth(
        wayBoundsWithDepth: [SIMD3<Float>], imageSize: CGSize,
        cameraTransform: simd_float4x4 = matrix_identity_float4x4,
        cameraIntrinsics: simd_float3x3 = matrix_identity_float3x3,
        deviceOrientation: UIDeviceOrientation = .landscapeLeft,
        originalImageSize: CGSize
    ) -> Float {
        guard wayBoundsWithDepth.count == 4 else {
            print("Invalid way bounds")
            return 0.0
        }
        
        print("Calculating way width with bounds")
        let deltas = wayBoundsWithDepth.map { point in
            return getDeltaFromPoint(
                pointWithDepth: point, imageSize: imageSize,
                cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics,
                deviceOrientation: deviceOrientation, originalImageSize: originalImageSize)
        }
        let lowerLeft = deltas[0]
        let upperLeft = deltas[1]
        let upperRight = deltas[2]
        let lowerRight = deltas[3]
        
        // Calculate the width in camera space
        let lowerWidth = simd_distance(lowerLeft, lowerRight)
        let upperWidth = simd_distance(upperLeft, upperRight)
        print(lowerWidth, upperWidth)
        
        // Average the widths
        let widthInMeters = (lowerWidth + upperWidth) / 2.0
        
        return widthInMeters
    }
    
    func getDeltaFromPoint(pointWithDepth: SIMD3<Float>, imageSize: CGSize,
                               cameraTransform: simd_float4x4 = matrix_identity_float4x4,
                               cameraIntrinsics: simd_float3x3 = matrix_identity_float3x3,
                               deviceOrientation: UIDeviceOrientation = .landscapeLeft,
                               originalImageSize: CGSize) -> SIMD3<Float> {
        // Invert the camera intrinsics to convert image coordinates to camera space
        let cameraInverseIntrinsics = simd_inverse(cameraIntrinsics)
        
        // Align the point with depth to ARKit's coordinate system
        let arKitPoint = alignVisionPointToARKitPoint(
            point: CGPoint(x: CGFloat(pointWithDepth.x), y: CGFloat(pointWithDepth.y)),
            imageSize: imageSize, originalImageSize: originalImageSize,
            deviceOrientation: deviceOrientation)
        let px = Float(arKitPoint.x) // Convert to Float for processing
        let py = Float(arKitPoint.y) // Convert to Float for processing
        
        // Create a 3D point in camera space
        let imagePoint = simd_float3(px, py, 1.0)
        let ray = cameraInverseIntrinsics * imagePoint
        let rayDirection = simd_normalize(ray)
        
        // Scale the ray direction by the depth value to get the actual point in camera space
        let depth = Float(pointWithDepth.z)
        var cameraPoint = rayDirection * depth
        // Fix the cameraPoint so that the y-axis points up
        // TODO: Check how to fix the discrepancy between ARKit image origin having y-axis pointing downwards
        // while the ARKit camera transform has the y-axis pointing upwards
        cameraPoint.y = -cameraPoint.y
        // Fix the cameraPoint so that the z-axis points south
        // TODO: Check why camera transform coordinates has the z-axis inverted
        cameraPoint.z = -cameraPoint.z
        let cameraPoint4 = simd_float4(cameraPoint, 1.0)
        
        // Transform the point from camera space to world space
        let worldPoint4 = cameraTransform * cameraPoint4
        let worldPoint = SIMD3<Float>(worldPoint4.x, worldPoint4.y, worldPoint4.z)
        
        // Get camera world coordinates
        let cameraOriginPoint = simd_make_float3(cameraTransform.columns.3.x,
                                                 cameraTransform.columns.3.y,
                                                 cameraTransform.columns.3.z)
        var delta = worldPoint - cameraOriginPoint
        delta.z = -delta.z // Fix the z-axis back so that it points north
        
//        print("Point with depth: \(pointWithDepth), px: \(px), py: \(py)")
//        print("Camera Intrinsics: \(cameraIntrinsics)")
//        print("Camera Inverse Intrinsics: \(cameraInverseIntrinsics)")
//        print("Ray: \(ray)")
//        print("Ray direction: \(rayDirection)")
//        print("Camera point in camera space: \(cameraPoint)")
//        print("Fixed Camera Transform: \(cameraTransform)")
//        print("World point in world space: \(worldPoint4)")
//        print("Camera origin point: \(cameraOriginPoint)")
        print("Delta: \(delta)")
        
        return delta
    }
    
    /**
     This function converts a normalized point in the image space to an unnormalized point in the ARKit frame.
        It takes into account the device orientation
     
     The ARKit frame has its origin at the top-left corner, with y-axis pointing downwards.
     On the other hand, the Vision framework has its origin at the bottom-left corner, with y-axis pointing upwards.
     */
    func alignVisionPointToARKitPoint(point: CGPoint, imageSize: CGSize,
                                 originalImageSize: CGSize, deviceOrientation: UIDeviceOrientation) -> CGPoint {
        // The following point aligns the Vision point's co-ordinate frame with the camera frame
        // (It does not change the origin configuration)
        var alignedPoint = point
        var alignTransform: CGAffineTransform = .identity
        switch (deviceOrientation) {
        case .portrait: // Rotate the point counter-clockwise by 90 degrees and add 1 to x-coordinate
            alignTransform = CGAffineTransform(translationX: 1, y: 0).rotated(by: .pi/2)
            break
        case .portraitUpsideDown: // Rotate the point clockwise by 90 degrees and add 1 to y-coordinate
            alignTransform = CGAffineTransform(translationX: 0, y: 1).rotated(by: -(.pi/2))
            break
        case .landscapeLeft: // No change needed for landscape left orientation
            break
        case .landscapeRight: // Rotate the point clockwise by 180 degrees and add 1 to both coordinates
            alignTransform = CGAffineTransform(translationX: 1, y: 1).rotated(by: .pi)
        default:
            break
        }
        // Apply the alignment transformation to the point
        alignedPoint = alignedPoint.applying(alignTransform)
        
        // Get the transformation to revert the image to its original size
        let transform: CGAffineTransform = CIImageUtils.transformRevertResizeWithAspectThenCrop(
            imageSize: imageSize, from: originalImageSize)
        // Apply the transformation to the point
        let newPoint = CGPoint(x: alignedPoint.x * imageSize.width, y: (1-alignedPoint.y) * imageSize.height)
        let transformedPoint = newPoint.applying(transform)
        
        return transformedPoint
    }
}
