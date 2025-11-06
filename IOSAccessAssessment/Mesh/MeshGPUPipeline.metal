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
        return float2(-1, -1);
    }
    float3 imagePoint = imageVertex.xyz / imageVertex.z;
    float xNormalized = - imagePoint.x / imagePoint.z;
    float yNormalized = - imagePoint.y / (- imagePoint.z);
    
    float3 pixelHomogeneous = intrinsics * float3(xNormalized, yNormalized, 1.0);
    float2 pixelCoord = pixelHomogeneous.xy / pixelHomogeneous.z;
    
    if (pixelCoord.x < 0 || pixelCoord.x >= imageSize.x ||
        pixelCoord.y < 0 || pixelCoord.y >= imageSize.y) {
        return float2(-1, -1);
    }
    float2 pixelCoordRounded = round(pixelCoord);
    return pixelCoordRounded;
}

kernel void processMesh(
    device const packed_float3*     positions      [[ buffer(0) ]],
    device const uint*              indices        [[ buffer(1) ]],
    device const uint8_t*           classesOpt     [[ buffer(2) ]], // may be null if hasClass == false
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
        return;
    }
    
    // Get classification
    uchar cls;
    if (Params.hasClass) {
        cls = classesOpt[faceId];
    } else {
        cls = -1;
    }
    if (cls != 2) {
        return;
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
    
// Map float <-> uint to preserve total ordering for atomics (handles negatives)
inline uint float_to_ordered_uint(float f) {
    uint u = as_type<uint>(f);
    return (u & 0x80000000u) ? (~u) : (u | 0x80000000u);
}
inline float ordered_uint_to_float(uint u) {
    return as_type<float>((u & 0x80000000u) ? (u & ~0x80000000u) : (~u));
}
inline void atomic_min_float(device atomic_uint* dstU, float v) {
    uint newU = float_to_ordered_uint(v);
    uint oldU = atomic_load_explicit(dstU, memory_order_relaxed);
    while (newU < oldU) {
        if (atomic_compare_exchange_weak_explicit(dstU, &oldU, newU,
                                                  memory_order_relaxed, memory_order_relaxed)) break;
    }
}
inline void atomic_max_float(device atomic_uint* dstU, float v) {
    uint newU = float_to_ordered_uint(v);
    uint oldU = atomic_load_explicit(dstU, memory_order_relaxed);
    while (newU > oldU) {
        if (atomic_compare_exchange_weak_explicit(dstU, &oldU, newU,
                                                  memory_order_relaxed, memory_order_relaxed)) break;
    }
}

kernel void processMeshGPU(
    device const packed_float3*     positions      [[ buffer(0) ]],
    device const uint*              indices        [[ buffer(1) ]],
    device const uint8_t*           classesOpt     [[ buffer(2) ]], // may be null if hasClass == false
    device packed_float3*           outVertices    [[ buffer(3) ]],
    device uint*                    outIndices     [[ buffer(4) ]],
    device atomic_uint*             outTriCount    [[ buffer(5) ]],
    constant FaceParams&            Params         [[ buffer(6) ]],
    device atomic_uint*             debugCounter   [[ buffer(7) ]],
    device atomic_uint*             aabbMinU       [[ buffer(8) ]],  // length 3
    device atomic_uint*             aabbMaxU       [[ buffer(9) ]],  // length 3
    uint                            faceId         [[ thread_position_in_grid ]]
) {
    if (faceId >= Params.faceCount) return;
    if (Params.hasClass != 0u) {
        uchar cls = classesOpt[faceId];
        if (cls != 2) return; // keep only class==2
    }

    const uint base = faceId * Params.indicesPerFace;
    const uint i0 = indices[base + 0];
    const uint i1 = indices[base + 1];
    const uint i2 = indices[base + 2];

    // Load local-space positions
    float3 p0 = positions[i0];
    float3 p1 = positions[i1];
    float3 p2 = positions[i2];
    
    // Transform to world space
    float3 w0 = (Params.anchorTransform * float4(p0, 1.0)).xyz;
    float3 w1 = (Params.anchorTransform * float4(p1, 1.0)).xyz;
    float3 w2 = (Params.anchorTransform * float4(p2, 1.0)).xyz;
    
    float3 centroid = (w0 + w1 + w2) / 3.0;
//
    // Project to camera space
    float2 pixel = projectWorldPointToPixel(centroid, Params.viewMatrix, Params.intrinsics, Params.imageSize);
    if (pixel.x < 0.0 || pixel.y < 0.0) {
        // Not visible
        return;
    }
    
    // Reserve a slot if available
    uint cur = atomic_load_explicit(outTriCount, memory_order_relaxed);
    if (cur >= Params.totalCount) return;
    uint triSlot = atomic_fetch_add_explicit(outTriCount, 1u, memory_order_relaxed);
    if (triSlot >= Params.totalCount) return; // guard against racing
    
    uint vBase = triSlot * 3u;
    outVertices[vBase + 0] = (packed_float3)(w0);
    outVertices[vBase + 1] = (packed_float3)(w1);
    outVertices[vBase + 2] = (packed_float3)(w2);
    
    outIndices[vBase + 0] = vBase + 0;
    outIndices[vBase + 1] = vBase + 1;
    outIndices[vBase + 2] = vBase + 2;
    
    // Update global AABB (atomic across all threads)
    atomic_min_float(&aabbMinU[0], w0.x); atomic_min_float(&aabbMinU[1], w0.y); atomic_min_float(&aabbMinU[2], w0.z);
    atomic_max_float(&aabbMaxU[0], w0.x); atomic_max_float(&aabbMaxU[1], w0.y); atomic_max_float(&aabbMaxU[2], w0.z);

    atomic_min_float(&aabbMinU[0], w1.x); atomic_min_float(&aabbMinU[1], w1.y); atomic_min_float(&aabbMinU[2], w1.z);
    atomic_max_float(&aabbMaxU[0], w1.x); atomic_max_float(&aabbMaxU[1], w1.y); atomic_max_float(&aabbMaxU[2], w1.z);

    atomic_min_float(&aabbMinU[0], w2.x); atomic_min_float(&aabbMinU[1], w2.y); atomic_min_float(&aabbMinU[2], w2.z);
    atomic_max_float(&aabbMaxU[0], w2.x); atomic_max_float(&aabbMaxU[1], w2.y); atomic_max_float(&aabbMaxU[2], w2.z);
}
