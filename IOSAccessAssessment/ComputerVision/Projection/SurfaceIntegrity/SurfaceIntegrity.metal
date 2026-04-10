//
//  SurfaceIntegrity.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/9/26.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;
#import "ShaderTypes.h"

// Needed for mesh normals which are not pre-aligned to reference direction
inline float3 alignNormalWithReference(float3 normal, float3 reference) {
    if (dot(normal, reference) < 0.0) {
        return -normal;
    }
    return normal;
}

kernel void countDeviantNormals(
    device const SurfaceNormalsForPointsGridCell* grid [[buffer(0)]],
    constant uint& width [[buffer(1)]],
    constant uint& height [[buffer(2)]],
    constant DeviantNormalParams& params [[buffer(3)]],
    device atomic_uint* totalValid [[buffer(4)]],
    device atomic_uint* totalDeviant [[buffer(5)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]]
) {
    threadgroup uint localValid[256];
    threadgroup uint localDeviant[256];
    
    uint valid = 0;
    uint deviant = 0;
    
    uint x = id % width;
    uint y = id / width;
    if (x < width && y < height) {
        SurfaceNormalsForPointsGridCell cell = grid[id];
        if (cell.isValid != 0) {
            valid = 1;
            float3 n = cell.surfaceNormal;
            float cosTheta = dot(n, params.normalVector);
            // clamp
            cosTheta = clamp(cosTheta, -1.0f, 1.0f);
            if (cosTheta < params.angularDeviationCosThreshold) {
                deviant = 1;
            }
        }
    }
    
    localValid[tid] = valid;
    localDeviant[tid] = deviant;
    
    // Perform parallel reduction within the threadgroup
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint offset = 128; offset > 0; offset /= 2) {
        if (tid < offset) {
            localValid[tid] += localValid[tid + offset];
            localDeviant[tid] += localDeviant[tid + offset];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // Thread 0 of the group writes the result to global memory
    if (tid == 0) {
        atomic_fetch_add_explicit(totalValid, localValid[0], memory_order_relaxed);
        atomic_fetch_add_explicit(totalDeviant, localDeviant[0], memory_order_relaxed);
    }
}

kernel void stdFromNormals(
    device const SurfaceNormalsForPointsGridCell* grid [[buffer(0)]],
    constant uint& width [[buffer(1)]],
    constant uint& height [[buffer(2)]],
    constant BoundsParams& boundsParams [[buffer(3)]],
    constant StdNormalParams& params [[buffer(4)]],
    device float* deviationSum [[buffer(5)]],
    device float* deviationSquaredSum [[buffer(6)]],
    device uint* totalValid [[buffer(7)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint gid [[threadgroup_position_in_grid]]
) {
    threadgroup float localDeviationSum[256];
    threadgroup float localDeviationSquaredSum[256];
    threadgroup uint localValid[256];
    
    float deviationThread = 0.0f;
    float deviationSquaredThread = 0.0f;
    uint validThread = 0;
    
    uint x = id % width;
    uint y = id / width;
    if (x >= boundsParams.minX && x <= boundsParams.maxX && y >= boundsParams.minY && y <= boundsParams.maxY) {
        SurfaceNormalsForPointsGridCell cell = grid[id];
        if (cell.isValid != 0) {
            validThread = 1;
            float3 n = cell.surfaceNormal;
            float cosTheta = dot(n, params.normalVector);
            // clamp
            cosTheta = clamp(cosTheta, -1.0f, 1.0f);
            float deviation = acos(cosTheta);
            deviationThread = deviation;
            deviationSquaredThread = deviation * deviation;
        }
    }
    
    localDeviationSum[tid] = deviationThread;
    localDeviationSquaredSum[tid] = deviationSquaredThread;
    localValid[tid] = validThread;
    
    // Perform parallel reduction within the threadgroup
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint offset = 128; offset > 0; offset /= 2) {
        if (tid < offset) {
            localDeviationSum[tid] += localDeviationSum[tid + offset];
            localDeviationSquaredSum[tid] += localDeviationSquaredSum[tid + offset];
            localValid[tid] += localValid[tid + offset];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // Thread 0 of the group writes the result to global memory
    if (tid == 0) {
        deviationSum[gid] = localDeviationSum[0];
        deviationSquaredSum[gid] = localDeviationSquaredSum[0];
        totalValid[gid] = localValid[0];
    }
}

kernel void countDeviantPolygonNormals(
    device const MeshTriangle* meshTriangles [[buffer(0)]],
    constant uint& count [[buffer(1)]],
    constant DeviantNormalParams& params [[buffer(3)]],
    device atomic_uint* totalValid [[buffer(4)]],
    device atomic_uint* totalDeviant [[buffer(5)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]]
) {
    threadgroup uint localValid[256];
    threadgroup uint localDeviant[256];
    
    uint valid = 0;
    uint deviant = 0;
    
    if (id < count) {
        valid = 1;
        MeshTriangle tri = meshTriangles[id];
        // Calculate normal from the points
        packed_float3 edge1 = tri.b - tri.a;
        packed_float3 edge2 = tri.c - tri.a;
        float3 normal = cross(edge1, edge2);
        normal = alignNormalWithReference(normal, params.normalVector);
        float cosTheta = dot(normal, params.normalVector);
        // clamp
        cosTheta = clamp(cosTheta, -1.0f, 1.0f);
        if (cosTheta < params.angularDeviationCosThreshold) {
            deviant = 1;
        }
    }
    
    localValid[tid] = valid;
    localDeviant[tid] = deviant;
    
    // Perform parallel reduction within the threadgroup
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint offset = 128; offset > 0; offset /= 2) {
        if (tid < offset) {
            localValid[tid] += localValid[tid + offset];
            localDeviant[tid] += localDeviant[tid + offset];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // Thread 0 of the group writes the result to global memory
    if (tid == 0) {
        atomic_fetch_add_explicit(totalValid, localValid[0], memory_order_relaxed);
        atomic_fetch_add_explicit(totalDeviant, localDeviant[0], memory_order_relaxed);
    }
}

kernel void areaWithinBoundsPolygon(
    device const MeshTriangle* meshTriangles [[buffer(0)]],
    constant uint& count [[buffer(1)]],
    constant BoundsParams& boundsParams [[buffer(2)]],
    device float* area [[buffer(3)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint gid [[threadgroup_position_in_grid]]
) {
    threadgroup float localArea[256];
    
    float areaThread = 0.0f;
    
    if (id < count) {
        MeshTriangle tri = meshTriangles[id];
        // Get the centroid and check if it's within bounds
        float3 centroid = (tri.a + tri.b + tri.c) / 3.0f;
        if (centroid.x >= boundsParams.minX && centroid.x <= boundsParams.maxX &&
            centroid.y >= boundsParams.minY && centroid.y <= boundsParams.maxY) {
            // Calculate area using cross product
            packed_float3 edge1 = tri.b - tri.a;
            packed_float3 edge2 = tri.c - tri.a;
            float triangleArea = length(cross(edge1, edge2)) / 2.0f;
            areaThread = triangleArea;
        }
    }
    
    localArea[tid] = areaThread;
    
    // Perform parallel reduction within the threadgroup
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint offset = 128; offset > 0; offset /= 2) {
        if (tid < offset) {
            localArea[tid] += localArea[tid + offset];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // Thread 0 of the group writes the result to global memory
    if (tid == 0) {
        area[gid] = localArea[0];
    }
}

kernel void stdFromPolygonNormals(
    device const MeshTriangle* meshTriangles [[buffer(0)]],
    constant uint& count [[buffer(1)]],
    constant BoundsParams& boundsParams [[buffer(2)]],
    constant StdNormalParams& params [[buffer(4)]],
    device float* deviationSum [[buffer(5)]],
    device float* deviationSquaredSum [[buffer(6)]],
    device uint* totalValid [[buffer(7)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]],
    uint gid [[threadgroup_position_in_grid]]
) {
    threadgroup float localDeviationSum[256];
    threadgroup float localDeviationSquaredSum[256];
    threadgroup uint localValid[256];
    
    float deviationThread = 0.0f;
    float deviationSquaredThread = 0.0f;
    uint validThread = 0;
    
    if (id < count) {
        MeshTriangle tri = meshTriangles[id];
        // Get the centroid and check if it's within bounds
        float3 centroid = (tri.a + tri.b + tri.c) / 3.0f;
        if (centroid.x >= boundsParams.minX && centroid.x <= boundsParams.maxX &&
            centroid.y >= boundsParams.minY && centroid.y <= boundsParams.maxY) {
            validThread = 1;
            // Calculate normal from the points
            packed_float3 edge1 = tri.b - tri.a;
            packed_float3 edge2 = tri.c - tri.a;
            float3 normal = cross(edge1, edge2);
            normal = alignNormalWithReference(normal, params.normalVector);
            float cosTheta = dot(normal, params.normalVector);
            // clamp
            cosTheta = clamp(cosTheta, -1.0f, 1.0f);
            float deviation = acos(cosTheta);
            deviationThread = deviation;
            deviationSquaredThread = deviation * deviation;
        }
    }
    
    localDeviationSum[tid] = deviationThread;
    localDeviationSquaredSum[tid] = deviationSquaredThread;
    localValid[tid] = validThread;
    
    // Perform parallel reduction within the threadgroup
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint offset = 128; offset > 0; offset /= 2) {
        if (tid < offset) {
            localDeviationSum[tid] += localDeviationSum[tid + offset];
            localDeviationSquaredSum[tid] += localDeviationSquaredSum[tid + offset];
            localValid[tid] += localValid[tid + offset];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // Thread 0 of the group writes the result to global memory
    if (tid == 0) {
        deviationSum[gid] = localDeviationSum[0];
        deviationSquaredSum[gid] = localDeviationSquaredSum[0];
        totalValid[gid] = localValid[0];
    }
}
