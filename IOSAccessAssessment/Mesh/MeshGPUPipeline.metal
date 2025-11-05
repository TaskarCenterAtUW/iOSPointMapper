//
//  MeshGPUPipeline.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//

#include <metal_stdlib>
using namespace metal;
#import "ShaderTypes.h"

// For debugging
enum DebugSlot : uint {
    zBelowZero = 0,
    outsideImage = 1,
    unknown = 2
};

inline float2 projectWorldPointToPixel(
    float3 worldPoint,
    constant float4x4& viewMatrix,
    constant float3x3& intrinsics,
    uint2 imageSize
) {
    float4 worldPoint4 = float4(worldPoint, 1.0);
    float4 imageVertex = viewMatrix * worldPoint4;
    
    if (imageVertex.z > 0) {
        return float2(-1000, -1000); // Point is behind the camera
    }
    float3 imagePoint = imageVertex.xyz / imageVertex.z;
    float xNormalized = - imagePoint.x / imagePoint.z;
    float yNormalized = - imagePoint.y / (- imagePoint.z);
    
    float3 pixelHomogeneous = intrinsics * float3(xNormalized, yNormalized, 1.0);
    float2 pixelCoord = pixelHomogeneous.xy / pixelHomogeneous.z;
    
    if (pixelCoord.x < 0 || pixelCoord.x >= imageSize.x ||
        pixelCoord.y < 0 || pixelCoord.y >= imageSize.y) {
        return float2(-2000, -2000); // Outside image bounds
    }
    float2 pixelCoordRounded = round(pixelCoord);
    return pixelCoordRounded;
}

kernel void processMesh(
    device const packed_float3*     positions      [[ buffer(0) ]],
    device const uint*              indices        [[ buffer(1) ]],
    device const uchar*             classesOpt     [[ buffer(2) ]], // may be null if hasClass == false
    device MeshTriangle*            outFaces       [[ buffer(3) ]],
    device atomic_uint*             outCount       [[ buffer(4) ]],
    constant FaceParams&            Params         [[ buffer(5) ]],
    device atomic_uint*             debugCounter   [[ buffer(6) ]],
    uint                            faceId         [[ thread_position_in_grid ]]
) {
    if (faceId >= Params.faceCount) return;

    const uint base = faceId * Params.indicesPerFace;
    const uint i0 = indices[base + 0];
    const uint i1 = indices[base + 1];
    const uint i2 = indices[base + 2];

    // Load local-space positions
    float3 p0 = positions[i0];
    float3 p1 = positions[i1];
    float3 p2 = positions[i2];
    
    // Transform to world space
    float4 wp0 = Params.anchorTransform * float4(p0, 1.0);
    float4 wp1 = Params.anchorTransform * float4(p1, 1.0);
    float4 wp2 = Params.anchorTransform * float4(p2, 1.0);
    
    float4 centroid = (wp0 + wp1 + wp2) / 3.0;
//    
    // Project to camera space
    float2 pixel = projectWorldPointToPixel(centroid.xyz, Params.viewMatrix, Params.intrinsics, Params.imageSize);
    if (pixel.x < 0.0 || pixel.y < 0.0) {
        // Not visible
        // Debugging aid, count how many faces were culled
        if (pixel.x == -1000 && pixel.y == -1000) {
            atomic_fetch_add_explicit(&debugCounter[zBelowZero], 1u, memory_order_relaxed);
        } else if (pixel.x == -2000 && pixel.y == -2000) {
            atomic_fetch_add_explicit(&debugCounter[outsideImage], 1u, memory_order_relaxed);
        }
        return;
    }
    
    // Get classification
    uchar cls;
    if (Params.hasClass) {
        cls = classesOpt[faceId];
    } else {
        cls = -1;
    }
    
    // reserve a slot if available
    if (atomic_load_explicit(outCount, memory_order_relaxed) >= Params.totalCount) {
        // No more space
        return;
    }
    uint slot = atomic_fetch_add_explicit(outCount, 1u, memory_order_relaxed);
    // Write result
    MeshTriangle outFace;
    outFace.a = wp0.xyz;
    outFace.b = wp1.xyz;
    outFace.c = wp2.xyz;
    outFaces[slot] = outFace;
}
    
