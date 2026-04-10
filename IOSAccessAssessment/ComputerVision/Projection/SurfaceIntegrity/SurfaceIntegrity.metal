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
    constant uint& width [[buffer(1)]],
    constant uint& height [[buffer(2)]],
    constant BoundsParams& boundsParams [[buffer(3)]],
    constant StdNormalParams& params [[buffer(4)]],
    device atomic_float* deviationSum [[buffer(5)]],
    device atomic_float* deviationSquaredSum [[buffer(6)]],
    device atomic_uint* totalValid [[buffer(7)]],
    uint id [[thread_position_in_grid]],
    uint tid [[thread_index_in_threadgroup]]
) {
    threadgroup float localDeviationSum[256];
    threadgroup float localDeviationSquaredSum[256];
    threadgroup uint localValid[256];
    
    float deviationSumThread = 0.0f;
    float deviationSquaredSumThread = 0.0f;
    uint valid = 0;
    
    uint x = id % width;
    uint y = id / width;
    if (x < width && y < height) {
        SurfaceNormalsForPointsGridCell cell = grid[id];
        if (cell.isValid != 0) {
            valid = 1;
            float3 n = cell.surfaceNormal;
            float cosTheta = dot(n, params.normalVector);
            float deviation = acos(cosTheta);
            deviationSumThread = deviation;
            deviationSquaredSumThread = deviation * deviation;
        }
    }
    
    localDeviationSum[tid] = deviationSumThread;
    localDeviationSquaredSum[tid] = deviationSquaredSumThread;
    localValid[tid] = valid;
    
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
        atomic_fetch_add_explicit(deviationSum, localDeviationSum[0], memory_order_relaxed);
        atomic_fetch_add_explicit(deviationSquaredSum, localDeviationSquaredSum[0], memory_order_relaxed);
        atomic_fetch_add_explicit(totalValid, localValid[0], memory_order_relaxed);
    }
}
