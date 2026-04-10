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
    constant BoundsParams& boundsParams [[buffer(1)]],
    constant StdNormalParams& params [[buffer(2)]],
    device atomic_float* deviationSum [[buffer(3)]],
    device atomic_float* deviationSquaredSum [[buffer(4)]],
    device atomic_uint* totalValid [[buffer(5)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]]
) {
    
}
