//
//  ProjectionUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/5/26.
//

import SwiftUI
import CoreImage
import simd

/**
 Struct that contains utility functions related to projection and coordinate transformations, such as projecting world points to screen space or calculating view directions. This can be used across the application wherever such transformations are needed, especially in the context of accessibility feature estimation and visualization.
 */
public struct ProjectionUtils {
    /**
        Projects a 2D pixel point with depth information to a 3D world point using the camera's transform and intrinsics.
     
        - Parameters:
            - pixelPoint: The 2D point in pixel coordinates that you want to project to world space.
            - depth: The depth value at the given pixel point, typically obtained from a depth map.
            - cameraTransform: The 4x4 transformation matrix representing the camera's position and orientation in world space.
            - cameraIntrinsics: The 3x3 matrix containing the camera's intrinsic parameters,
     
        - NOTE:
        Because of the inefficiency of matrix inversion, it's recommended to precompute the inverse of the camera intrinsics matrix if projecting multiple points, and use the version of this function that accepts the inverse directly.
     */
    public static func projectPixelToWorld(
        pixelPoint: CGPoint,
        depth: Float,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) -> simd_float3 {
        let invCameraIntrinsics = cameraIntrinsics.inverse
        return self.projectPixelToWorld(
            pixelPoint: pixelPoint, depth: depth,
            cameraTransform: cameraTransform, invCameraIntrinsics: invCameraIntrinsics
        )
    }
    
    /**
     Projects a 2D pixel point with depth information to a 3D world point using the camera's transform and the precomputed inverse of the camera intrinsics.
     
     - Parameters:
        - pixelPoint: The 2D point in pixel coordinates that you want to project to world space.
        - depth: The depth value at the given pixel point, typically obtained from a depth map.
        - cameraTransform: The 4x4 transformation matrix representing the camera's position and orientation in world space.
        - invCameraIntrinsics: The precomputed inverse of the camera's intrinsic parameters matrix.
     */
    public static func projectPixelToWorld(
        pixelPoint: CGPoint,
        depth: Float,
        cameraTransform: simd_float4x4,
        invCameraIntrinsics: simd_float3x3
    ) -> simd_float3 {
        let imagePoint = simd_float3(Float(pixelPoint.x), Float(pixelPoint.y), 1.0)
        let ray = invCameraIntrinsics * imagePoint
        let rayDirection = simd_normalize(ray)
        
        var cameraSpacePoint = rayDirection * depth
        cameraSpacePoint.y = -cameraSpacePoint.y // Flip the y-axis to match the coordinate system used in ARKit
        cameraSpacePoint.z = -cameraSpacePoint.z // Flip the z-axis to match the coordinate system used in ARKit
        let cameraSpacePoint4 = simd_float4(cameraSpacePoint, 1.0)
        
        let worldSpacePoint4 = cameraTransform * cameraSpacePoint4
        let worldPoint = simd_float3(worldSpacePoint4.x, worldSpacePoint4.y, worldSpacePoint4.z) / worldSpacePoint4.w
        
        return worldPoint
    }
    
    /**
        Projects a 3D world point to 2D pixel coordinates using the camera's transform and intrinsics.
     
        - Parameters:
            - worldPoint: The 3D point in world coordinates that you want to project to pixel space.
            - cameraTransform: The 4x4 transformation matrix representing the camera's position and orientation in world space.
            - cameraIntrinsics: The 3x3 matrix containing the camera's intrinsic parameters.
            - imageSize: The size of the image in pixels, used to check if the projected
     
        - Returns: The projected 2D pixel coordinates if the world point is in front of the camera and within the image bounds, otherwise returns nil.
     
        - NOTE:
        Because of the inefficiency of matrix inversion, it's recommended to precompute the inverse of the camera transform if projecting multiple points, and use the version of this function that accepts the view matrix directly.
     */
    public static func unprojectWorldToPixel(
        worldPoint: simd_float3,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) -> CGPoint? {
        let viewMatrix = cameraTransform.inverse
        return self.unprojectWorldToPixel(
            worldPoint: worldPoint, viewMatrix: viewMatrix, cameraIntrinsics: cameraIntrinsics, imageSize: imageSize
        )
    }
    
    /**
        Projects a 3D world point to 2D pixel coordinates using the view matrix and camera intrinsics.
     
        - Parameters:
            - worldPoint: The 3D point in world coordinates that you want to project to pixel space.
            - viewMatrix: The precomputed inverse of the camera transform, representing the transformation from world space to camera space.
            - cameraIntrinsics: The 3x3 matrix containing the camera's intrinsic parameters.
            - imageSize: The size of the image in pixels, used to check if the projected point is within the image bounds.
     */
    public static func unprojectWorldToPixel(
        worldPoint: simd_float3,
        viewMatrix: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) -> CGPoint? {
        let worldPoint4 = simd_float4(worldPoint, 1.0)
        let clipSpacePoint = viewMatrix * worldPoint4
        
        guard clipSpacePoint.z < 0 else {
            return nil
        }
        
        // Normalized image coordinates (flip y to match image coordinate system)
        let ndcX = clipSpacePoint.x / -clipSpacePoint.z
        let ndcY = -clipSpacePoint.y / -clipSpacePoint.z
        
        let ndcPoint = simd_float3(ndcX, ndcY, 1.0)
        let imagePoint = cameraIntrinsics * ndcPoint
//        let pX = imagePoint.x
//        let pY = imagePoint.y
        
        guard imagePoint.x.isFinite, imagePoint.y.isFinite else {
            return nil
        }
        let pX = Int(floor(imagePoint.x))
        let pY = Int(floor(imagePoint.y))
        guard pX >= 0, pY >= 0, pX < Int(imageSize.width), pY < Int(imageSize.height) else {
            return nil
        }
        return CGPoint(x: CGFloat(pX), y: CGFloat(pY))
    }
}
