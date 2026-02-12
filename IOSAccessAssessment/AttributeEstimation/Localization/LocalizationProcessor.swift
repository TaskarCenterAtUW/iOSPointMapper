//
//  LocalizationProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreImage
import CoreLocation
import simd

struct PointWithDepth: Sendable, Equatable, Hashable, Codable {
    let point: CGPoint
    let depth: Float
}

enum LocalizationProcessorError: Error, LocalizedError {
    case invalidBounds
    case divisionByZero
    
    var errorDescription: String? {
        switch self {
        case .invalidBounds:
            return "The provided bounds for localization are invalid."
        case .divisionByZero:
            return "A division by zero occurred during localization calculations."
        }
    }
}

struct LocalizationProcessor {
    let RADIUS = 6378137.0
    
    /**
        Calculate the location of an object at a given point with depth in the image.
     
        - Parameters:
            - point: The CGPoint in normalized image coordinates (0 to 1) where the object is located.
            - depth: The depth value (in meters) at the given point.
            - imageSize: The size of the image from which the point is taken.
            - cameraTransform: The camera transform matrix.
            - cameraIntrinsics: The camera intrinsics matrix.
            - deviceLocation: The current location of the device.
     
        - Returns: The calculated CLLocationCoordinate2D of the object.
     
        - Throws: `LocalizationProcessorError.invalidBounds` if the provided bounds are not valid.
     
        - Note: Assumes that ARKit has the world alignment set to `ARWorldAlignment.gravityAndHeading`.
     */
    func calculateLocation(
        point: CGPoint, depth: Float, imageSize: CGSize,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        deviceLocation: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let delta = getDeltaFromPoint(
            point: point, depth: depth, imageSize: imageSize,
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics
        )
        let latitudeDelta = -delta.z
        let longitudeDelta = delta.x
        return self.calculateLocation(
            latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta,
            deviceLocation: deviceLocation
        )
    }
    
    func calculateLocation(
        worldPoint: SIMD3<Float>,
        cameraTransform: simd_float4x4,
        deviceLocation: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let cameraOriginPoint = simd_make_float3(cameraTransform.columns.3.x,
                                                 cameraTransform.columns.3.y,
                                                 cameraTransform.columns.3.z)
        let delta = worldPoint - cameraOriginPoint
        let latitudeDelta = -delta.z
        let longitudeDelta = delta.x
        return self.calculateLocation(
            latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta,
            deviceLocation: deviceLocation
        )
    }
    
    /**
        Calculate the latitude and longitude deltas of an object at a given point with depth in the image.
     
        - NOTE: This method is primarily for testing and debugging purposes.
     */
    func calculateDelta(
        point: CGPoint, depth: Float, imageSize: CGSize,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) -> SIMD2<Float> {
        let delta = getDeltaFromPoint(
            point: point, depth: depth, imageSize: imageSize,
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics
        )
        return SIMD2<Float>( -delta.z, delta.x )
    }
    
    func calculateDelta(
        worldPoint: SIMD3<Float>,
        cameraTransform: simd_float4x4
    ) -> SIMD2<Float> {
        let cameraOriginPoint = simd_make_float3(cameraTransform.columns.3.x,
                                                 cameraTransform.columns.3.y,
                                                 cameraTransform.columns.3.z)
        let delta = worldPoint - cameraOriginPoint
        return SIMD2<Float>( -delta.z, delta.x )
    }
    
    func calculateLocation(
        latitudeDelta: Float, longitudeDelta: Float,
        deviceLocation: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        /// Calculate distance and bearing
        let distance = Double(sqrt(latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta))
        let bearing = Double(atan2(longitudeDelta, latitudeDelta))
        
        /// Convert to radians
        let deviceLatitude = deviceLocation.latitude * .pi / 180.0
        let deviceLongitude = deviceLocation.longitude * .pi / 180.0
        
        let angularDistance = distance / RADIUS
        
        let calculatedLatitudeA = sin(deviceLatitude) * cos(angularDistance)
        let calculatedLatitudeB = cos(deviceLatitude) * sin(angularDistance) * cos(bearing)
        let calculatedLatitude = asin(calculatedLatitudeA + calculatedLatitudeB)
        
        let calculatedLongitudeA = sin(bearing) * sin(angularDistance) * cos(deviceLatitude)
        let calculatedLongitudeB = cos(angularDistance) - sin(deviceLatitude) * sin(calculatedLatitude)
        let calculatedLongitude = deviceLongitude + atan2(calculatedLongitudeA, calculatedLongitudeB)
        
        /// Convert back to degrees
        let calculatedLatitudeCoordinate = calculatedLatitude * 180.0 / .pi
        let calculatedLongitudeCoordinate = calculatedLongitude * 180.0 / .pi
        
        return CLLocationCoordinate2D(
            latitude: calculatedLatitudeCoordinate,
            longitude: calculatedLongitudeCoordinate
        )
    }
    
    func getDeltaFromPoint(
        point: CGPoint, depth: Float, imageSize: CGSize,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) -> SIMD3<Float> {
        /// Invert the camera intrinsics to convert image coordinates to camera space
        let cameraInverseIntrinsics = simd_inverse(cameraIntrinsics)
        
        let alignedPoint = getAlignedPoint(point: point, imageSize: imageSize)
        let px = Float(alignedPoint.x)
        let py = Float(alignedPoint.y)
        
        let imagePoint = simd_float3(px, py, 1.0)
        let ray = cameraInverseIntrinsics * imagePoint
        let rayDirection = simd_normalize(ray)
        
        /// Scale the ray direction by the depth value to get the actual point in camera space
        var cameraPoint = rayDirection * depth
        /// Fix the cameraPoint so that the y-axis points up
        cameraPoint.y = -cameraPoint.y
        /// Fix the cameraPoint so that the z-axis points south
        cameraPoint.z = -cameraPoint.z
        let cameraPoint4 = simd_float4(cameraPoint, 1.0)
        
        /// Transform the point from camera space to world space
        let worldPoint4 = cameraTransform * cameraPoint4
        let worldPoint = SIMD3<Float>(worldPoint4.x, worldPoint4.y, worldPoint4.z) / worldPoint4.w
        
        // Get camera world coordinates
        let cameraOriginPoint = simd_make_float3(cameraTransform.columns.3.x,
                                                 cameraTransform.columns.3.y,
                                                 cameraTransform.columns.3.z)
        var delta = worldPoint - cameraOriginPoint
        
        return delta
    }
    
    private func getAlignedPoint(point: CGPoint, imageSize: CGSize) -> CGPoint {
        return CGPoint(x: point.x * imageSize.width, y: (1-point.y) * imageSize.height)
    }
}

/**
 Methods to calculate specific additional attributes of a localized object.
 */
extension LocalizationProcessor {
    /**
        Calculate the width of an object given its trapezoid bounds with depth information.
        
        - Parameters:
            - trapezoidBoundsWithDepth: An array of four tuples containing the CGPoint and depth Float for each corner of the trapezoid, in image normalized coordinates.
            Trapezoid corners should be ordered as: bottom-left, top-left, top-right, bottom-right.
            - imageSize: The size of the image from which the points are taken.
            - cameraTransform: The camera transform matrix.
            - cameraIntrinsics: The camera intrinsics matrix.
            - deviceLocation: The current location of the device.
     
        - Returns: The calculated width of the object as a Float.
     
        - Throws: `LocalizationProcessorError.invalidBounds` if the provided bounds are not valid.
     
     
        - Note: Assumes that ARKit has the world alignment set to `ARWorldAlignment.gravityAndHeading`.
        - Note: This method is part of a rudimentary width calculation logic that restricts the object to a trapezoidal shape.
     
        TODO: Improve upon this basic width calculation method.
     */
    func calculateWidth(
        trapezoidBoundsWithDepth: [PointWithDepth], imageSize: CGSize,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) throws -> Float {
        guard trapezoidBoundsWithDepth.count == 4 else {
            throw LocalizationProcessorError.invalidBounds
        }
        let trapezoidDeltas = trapezoidBoundsWithDepth.map { pointWithDepth in
            let delta = getDeltaFromPoint(
                point: pointWithDepth.point, depth: pointWithDepth.depth, imageSize: imageSize,
                cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
            )
            var deltaNorth = delta
            deltaNorth.z = -deltaNorth.z
            return deltaNorth
        }
        let bottomLeft = trapezoidDeltas[0]
        let topLeft = trapezoidDeltas[1]
        let topRight = trapezoidDeltas[2]
        let bottomRight = trapezoidDeltas[3]
        
        let bottomWidth = simd_length(bottomRight - bottomLeft)
        let topWidth = simd_length(topRight - topLeft)
        
        let width = (bottomWidth + topWidth) / 2.0
        return width
    }
    
    /**
     Calculate the running slope of an object given its trapezoid bounds with depth information.
     
        - Parameters:
            - trapezoidBoundsWithDepth: An array of four tuples containing the CGPoint and depth Float for each corner of the trapezoid, in image normalized coordinates.
            Trapezoid corners should be ordered as: bottom-left, top-left, top-right, bottom-right.
            - imageSize: The size of the image from which the points are taken.
            - cameraTransform: The camera transform matrix.
            - cameraIntrinsics: The camera intrinsics matrix.
     
        - Returns: The calculated running slope of the object in degrees as a Float.
     
        - Throws: `LocalizationProcessorError.invalidBounds` if the provided bounds are not valid.
                     `LocalizationProcessorError.divisionByZero` if a division by zero occurs during calculations.
      
        - Note: Assumes that ARKit has the world alignment set to `ARWorldAlignment.gravityAndHeading`.
        - Note: This method is part of a rudimentary slope calculation logic that restricts the object to a trapezoidal shape.
     
        TODO: Improve upon this basic slope calculation method.
     */
    func calculateRunningSlope(
        trapezoidBoundsWithDepth: [PointWithDepth], imageSize: CGSize,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) throws -> Float {
        guard trapezoidBoundsWithDepth.count == 4 else {
            throw LocalizationProcessorError.invalidBounds
        }
        let trapezoidDeltas = trapezoidBoundsWithDepth.map { pointWithDepth in
            let delta = getDeltaFromPoint(
                point: pointWithDepth.point, depth: pointWithDepth.depth, imageSize: imageSize,
                cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
            )
            var deltaNorth = delta
            deltaNorth.z = -deltaNorth.z
            return deltaNorth
        }
        let bottomLeft = trapezoidDeltas[0]
        let topLeft = trapezoidDeltas[1]
        let topRight = trapezoidDeltas[2]
        let bottomRight = trapezoidDeltas[3]
        
        let topMidpoint = (topLeft + topRight) / 2.0
        let bottomMidpoint = (bottomLeft + bottomRight) / 2.0
        
        let verticalDistance = topMidpoint.y - bottomMidpoint.y
        let horizontalDistance = simd_distance(
            SIMD2<Float>(topMidpoint.x, topMidpoint.z),
            SIMD2<Float>(bottomMidpoint.x, bottomMidpoint.z)
        )
        guard horizontalDistance != 0 else {
            throw LocalizationProcessorError.divisionByZero
        }
        let slope = atan(verticalDistance / horizontalDistance)
        let slopeInDegrees = slope * 180.0 / .pi
        return slopeInDegrees
    }
    
    func calculateCrossSlope(
        trapezoidBoundsWithDepth: [PointWithDepth], imageSize: CGSize,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) throws -> Float {
        guard trapezoidBoundsWithDepth.count == 4 else {
            throw LocalizationProcessorError.invalidBounds
        }
        let trapezoidDeltas = trapezoidBoundsWithDepth.map { pointWithDepth in
            let delta = getDeltaFromPoint(
                point: pointWithDepth.point, depth: pointWithDepth.depth, imageSize: imageSize,
                cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
            )
            var deltaNorth = delta
            deltaNorth.z = -deltaNorth.z
            return deltaNorth
        }
        let bottomLeft = trapezoidDeltas[0]
        let topLeft = trapezoidDeltas[1]
        let topRight = trapezoidDeltas[2]
        let bottomRight = trapezoidDeltas[3]
        
        let leftMidpoint = (bottomLeft + topLeft) / 2.0
        let rightMidpoint = (bottomRight + topRight) / 2.0
        
        let verticalDistance = leftMidpoint.y - rightMidpoint.y
        let horizontalDistance = simd_distance(
            SIMD2<Float>(leftMidpoint.x, leftMidpoint.z),
            SIMD2<Float>(rightMidpoint.x, rightMidpoint.z)
        )
        guard horizontalDistance != 0 else {
            throw LocalizationProcessorError.divisionByZero
        }
        let slope = atan(verticalDistance / horizontalDistance)
        let slopeInDegrees = slope * 180.0 / .pi
        return slopeInDegrees
    }
}
