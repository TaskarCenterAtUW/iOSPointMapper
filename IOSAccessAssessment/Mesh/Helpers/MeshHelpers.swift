//
//  MeshCPUUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/27/25.
//

import simd

/**
    Helper functions for processing mesh polygons on the CPU.
 */
struct MeshHelpers {
    static func getPolygonsCoordinates(
        meshPolygons: [MeshPolygon],
        viewMatrix: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        originalSize: CGSize
    ) -> [(SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)] {
        var trianglePoints: [(SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)] = []
//        let originalWidth = Float(originalSize.width)
//        let originalHeight = Float(originalSize.height)
        for meshPolygon in meshPolygons {
            let (v0, v1, v2) = (meshPolygon.v0, meshPolygon.v1, meshPolygon.v2)
            let worldPoints = [v0, v1, v2].map {
                projectWorldToPixel(
                    $0,
                    viewMatrix: viewMatrix,
                    intrinsics: cameraIntrinsics,
                    imageSize: originalSize
                )
            }
            guard let p0 = worldPoints[0],
                  let p1 = worldPoints[1],
                  let p2 = worldPoints[2] else {
                continue
            }
            trianglePoints.append((p0, p1, p2))
        }
        
        return trianglePoints
    }
    
    static func projectWorldToPixel(
        _ world: simd_float3,
        viewMatrix: simd_float4x4, // (world->camera)
        intrinsics K: simd_float3x3,
        imageSize: CGSize
    ) -> SIMD2<Float>? {
       let p4   = simd_float4(world, 1.0)
       let pc   = viewMatrix * p4                                  // camera space
       let x = pc.x, y = pc.y, z = pc.z
       
       guard z < 0 else {
           return nil
       }                       // behind camera
       
       // normalized image plane coords (flip Y so +Y goes up in pixels)
       let xn = x / -z
       let yn = -y / -z
       
       // intrinsics (column-major)
       let fx = K.columns.0.x
       let fy = K.columns.1.y
       let cx = K.columns.2.x
       let cy = K.columns.2.y
       
       // pixels in sensor/native image coordinates
       let u = fx * xn + cx
       let v = fy * yn + cy
       
       if u.isFinite && v.isFinite &&
           u >= 0 && v >= 0 &&
           u < Float(imageSize.width) && v < Float(imageSize.height) {
           return SIMD2<Float>(u.rounded(), v.rounded())
       }
       return nil
   }
}
