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

// Plane Fitting Point Extraction Kernel
// Assumes the depth texture is the same size as the segmentation texture
kernel void computeWorldPoints(
  texture2d<float, access::read> segmentationTexture [[texture(0)]],
  texture2d<float, access::read> depthTexture [[texture(1)]],
  constant uint8_t& targetValue [[buffer(0)]],
  constant PlanePointsParams& params [[buffer(1)]],
  device PlanePoint* points [[buffer(2)]],
  device atomic_uint* pointCount [[buffer(3)]],
  uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= segmentationTexture.get_width() || gid.y >= segmentationTexture.get_height())
        return;
    
    float4 pixelColor = segmentationTexture.read(gid);
    float grayscale = pixelColor.r;
    
    // Normalize grayscale to the range of the LUT
    uint index = min(uint(round(grayscale * 255.0)), 255u);
    if (index != targetValue) {
        return;
    }
    float depthValue = depthTexture.read(gid).r;
    if (depthValue <= params.minDepthThreshold || depthValue >= params.maxDepthThreshold) {
        return;
    }
    
    float3 worldPoint = projectPixelToWorld(
        float2(gid),
        depthValue,
        params.cameraTransform, 
        params.invIntrinsics
    );
    
    uint idx = atomic_fetch_add_explicit(pointCount, 1u, memory_order_relaxed);
    points[idx].p = worldPoint;
}
