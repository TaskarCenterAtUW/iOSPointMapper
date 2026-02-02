//
//  PlaneFitting.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/24/26.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;
#import "ShaderTypes.h"

enum PlaneDebugSlot : uint {
    outsideImage = 0,
    unmatchedSegmentation = 1,
    belowDepthRange = 2,
    aboveDepthRange = 3,
    wrotePoint = 4,
    depthIsZero = 5,
    // add more if needed
};

inline float3 projectPixelToWorld(
  float2 pixelCoord,
  float depthValue,
  constant float4x4& cameraTransform,
  constant float3x3& invIntrinsics
) {
    float3 imagePoint = float3(pixelCoord, 1.0);
    float3 ray = invIntrinsics * imagePoint;
    float3 rayDirection = normalize(ray);
    
    float3 cameraPoint = rayDirection * depthValue;
    cameraPoint = float3(cameraPoint.x, -cameraPoint.y, -cameraPoint.z);
    float4 cameraPoint4 = float4(cameraPoint, 1.0);
    
    float4 worldPoint4 = cameraTransform * cameraPoint4;
    float3 worldPoint = worldPoint4.xyz / worldPoint4.w;
    
    return worldPoint;
}

// Function to compute world points from segmentation and depth textures
// Assumes the depth texture is the same size as the segmentation texture
kernel void computeWorldPoints(
  texture2d<float, access::read> segmentationTexture [[texture(0)]],
  texture2d<float, access::read> depthTexture [[texture(1)]],
  constant uint8_t& targetValue [[buffer(0)]],
  constant WorldPointsParams& params [[buffer(1)]],
  device WorldPoint* points [[buffer(2)]],
  device atomic_uint* pointCount [[buffer(3)]],
  device atomic_uint* debugCounts [[buffer(4)]],
  uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= segmentationTexture.get_width() || gid.y >= segmentationTexture.get_height()) {
        atomic_fetch_add_explicit(&debugCounts[outsideImage], 1u, memory_order_relaxed);
        return;
    }
    
    float4 pixelColor = segmentationTexture.read(gid);
    float grayscale = pixelColor.r;
    
    // Normalize grayscale to the range of the LUT
    uint index = min(uint(round(grayscale * 255.0)), 255u);
    if (index != targetValue) {
        atomic_fetch_add_explicit(&debugCounts[unmatchedSegmentation], 1u, memory_order_relaxed);
        return;
    }
    float depthValue = depthTexture.read(gid).r;
    if (depthValue < params.minDepthThreshold) {
        atomic_fetch_add_explicit(&debugCounts[belowDepthRange], 1u, memory_order_relaxed);
        return;
    }
    if (depthValue > params.maxDepthThreshold) {
        atomic_fetch_add_explicit(&debugCounts[aboveDepthRange], 1u, memory_order_relaxed);
        return;
    }
    if (depthValue == 0.0f) {
        atomic_fetch_add_explicit(&debugCounts[depthIsZero], 1u, memory_order_relaxed);
    }
    
    float3 worldPoint = projectPixelToWorld(
        float2(gid),
        depthValue,
        params.cameraTransform, 
        params.invIntrinsics
    );
    atomic_fetch_add_explicit(&debugCounts[wrotePoint], 1u, memory_order_relaxed);
    
    uint idx = atomic_fetch_add_explicit(pointCount, 1u, memory_order_relaxed);
    points[idx].p = worldPoint;
}

// Function to project world points along a plane (longitudinal and lateral axes)
kernel void projectPointsToPlane(
    device const WorldPoint* inputPoints [[buffer(0)]],
    constant uint& pointCount [[buffer(1)]],
    constant ProjectedPointsParams& params [[buffer(2)]],
    device ProjectedPoint* outputPoints [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= pointCount) return;
    float3 longitudinalVector = normalize(params.longitudinalVector);
    float3 lateralVector = normalize(params.lateralVector);
    float3 origin = params.origin;
    
    float3 point = inputPoints[id].p;
    float s = dot(point - origin, longitudinalVector);
    float t = dot(point - origin, lateralVector);
    outputPoints[id].s = s;
    outputPoints[id].t = t;
}
