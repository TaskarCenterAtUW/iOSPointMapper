//
//  Plane.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/2/26.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;
#import "ShaderTypes.h"

kernel void binProjectedPoints(
   device const ProjectedPoint* inputPoints [[buffer(0)]],
   constant uint& pointCount [[buffer(1)]],
   constant ProjectedPointBinningParams& params [[buffer(2)]],
   device atomic_uint* binValueCounts [[buffer(3)]],
   device float* binTValues [[buffer(4)]],
   uint id [[thread_position_in_grid]]
) {
    if (id >= pointCount) return;
    float s = inputPoints[id].s;
    float t = inputPoints[id].t;
    
    // Gate by s limits
    if (s < params.sMin || s > params.sMax) { return; }
    
    uint bin = uint(floor((s - params.sMin) / params.sBinSize));
    if (bin >= params.binCount) { return; }
    
    uint count = atomic_fetch_add_explicit(&binValueCounts[bin], 1u, memory_order_relaxed);
    if (count < params.maxValuesPerBin) {
        binTValues[bin * params.maxValuesPerBin + count] = t;
    }
}

inline float dotVertexToLongitudinal(packed_float3 v, MTL_FLOAT3 longitudinalVector, MTL_FLOAT3 pointCurrentS) {
    MTL_FLOAT3 vertexToCurrentS = MTL_FLOAT3(v) - pointCurrentS;
    return dot(vertexToCurrentS, longitudinalVector);
}

// The uint2 id serves a dual purpose
// id.x is the triangle index, while id.y is the bin index corresponding to the currentS value for this pass.
kernel void binMeshTriangles(
    device const MeshTriangle* triangles [[buffer(0)]],
    constant float* binSValues [[buffer(1)]],
    constant uint& triangleCount [[buffer(2)]],
    constant uint& sBinCount [[buffer(3)]],
    constant MeshTriangleBinningParams& params [[buffer(4)]],
    device atomic_uint* binTriangleCounts [[buffer(5)]],
    device MeshTriangle* binTValues [[buffer(6)]],
    uint2 id [[thread_position_in_grid]]
) {
    if (id.x >= triangleCount) return;
    if (id.y >= sBinCount) return;
    MeshTriangle tri = triangles[id.x];
    float currentS = binSValues[id.y];
    
    MTL_FLOAT3 longitudinalVector = params.longitudinalVector;
    MTL_FLOAT3 lateralVector = params.lateralVector;
    MTL_FLOAT3 origin = params.origin;
    MTL_FLOAT3 pointCurrentS = origin + longitudinalVector * currentS;
    
    // For each vertex of the triangle,
    // check the dot product between the longitudinal vector and the vector from the point at currentS to the vertex
    float dot0 = dotVertexToLongitudinal(tri.a, longitudinalVector, pointCurrentS);
    float dot1 = dotVertexToLongitudinal(tri.b, longitudinalVector, pointCurrentS);
    float dot2 = dotVertexToLongitudinal(tri.c, longitudinalVector, pointCurrentS);
    
    // If all vertices are on the same side of the plane defined by currentS, skip this triangle
    if ((dot0 > 0 && dot1 > 0 && dot2 > 0) || (dot0 < 0 && dot1 < 0 && dot2 < 0)) {
        return;
    }
    
    uint bin = uint(floor((currentS - params.sMin) / params.sBinSize));
    if (bin >= params.binCount) { return; }
    
    uint count = atomic_fetch_add_explicit(&binTriangleCounts[bin], 1u, memory_order_relaxed);
    if (count < params.maxTrianglesPerBin) {
        binTValues[bin * params.maxTrianglesPerBin + count] = tri;
    }
}
