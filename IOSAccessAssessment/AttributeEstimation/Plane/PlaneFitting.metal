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
  constant float3x3& invIntrinsics,
  uint2 imageSize
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
