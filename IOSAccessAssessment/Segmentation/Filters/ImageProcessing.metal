//
//  kernel.metal
//  IOSAccessAssessment
//
//  Created by Sai on 4/17/24.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" kernel void colorMatchingKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float* grayscaleValues [[buffer(0)]],
    constant float3* colorValues [[buffer(1)]],
    constant uint& grayscaleCount [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height())
        return;

    float4 pixelColor = inputTexture.read(gid);
    float grayscale = pixelColor.r;

    for (uint i = 0; i < grayscaleCount; i++) {
        if (grayscale == grayscaleValues[i]) {
            pixelColor.rgb = colorValues[i];
            pixelColor.a = 0.9;
            outputTexture.write(pixelColor, gid);
            return;
        }
    }

    pixelColor = float4(0.0, 0.0, 0.0, 0.0);
    outputTexture.write(pixelColor, gid);
}

extern "C"
kernel
void colorMatchingKernelLUT (
     texture2d<float, access::read> inputTexture [[texture(0)]],
     texture2d<float, access::write> outputTexture [[texture(1)]],
     constant float3* colorLUT [[buffer(0)]], // Look-up Table with 256 colors
     uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height())
        return;
    
    float4 pixelColor = inputTexture.read(gid);
    float grayscale = pixelColor.r;
    
    // Normalize grayscale to the range of the LUT
    uint index = min(uint(round(grayscale * 255.0)), 255u);
    float3 newColor = colorLUT[index];
    
    if (newColor.r == 0.0 && newColor.g == 0.0 && newColor.b == 0.0) {
        pixelColor = float4(0.0, 0.0, 0.0, 0.0);
    } else {
        pixelColor = float4(newColor.r, newColor.g, newColor.b, 0.9);
    }
    outputTexture.write(pixelColor, gid);
}

// This kernel is used to create a binary mask based on a target value.
extern "C"
kernel
void binaryMaskingKernel (
      texture2d<float, access::read> inputTexture [[texture(0)]],
      texture2d<float, access::write> outputTexture [[texture(1)]],
      constant uint8_t& targetValue [[buffer(0)]],
      uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height())
        return;

    float4 pixelColor = inputTexture.read(gid);
    float grayscale = pixelColor.r;
    
    // Normalize grayscale to the range of the LUT
    uint8_t index = min(uint(round(grayscale * 255.0)), 255u);
    if (index == targetValue) {
        pixelColor = float4(0.0, 0.0, 0.0, 0.0);
    } else {
        pixelColor = float4(1.0, 1.0, 1.0, 1.0);
    }
    outputTexture.write(pixelColor, gid);
}

extern "C"
kernel
void dimensionBasedMaskingKernel (
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float& minX [[buffer(0)]], // Normalized coordinates
    constant float& maxX [[buffer(1)]],
    constant float& minY [[buffer(2)]],
    constant float& maxY [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint width = inputTexture.get_width();
    uint height = inputTexture.get_height();

    if (gid.x >= width || gid.y >= height)
        return;
    
    float4 pixelColor = inputTexture.read(gid);

    float normX = float(gid.x) / float(width);
    float normY = float(gid.y) / float(height);

    if (normX < minX || normX > maxX || normY < minY || normY > maxY) {
        pixelColor = float4(0.0, 0.0, 0.0, 0.0); // Transparent
    }
    
    outputTexture.write(pixelColor, gid);
}
                                  
                                  
kernel void warpPointsKernel(
    device const float2* inputPoints [[buffer(0)]],
    device float2* outputPoints [[buffer(1)]],
    constant float3x3& inverseHomography [[buffer(2)]],
    uint id [[thread_position_in_grid]])
{
    float2 point = inputPoints[id];
    float3 homogeneous = float3(point, 1.0);

    float3 warped = inverseHomography * homogeneous;
    float2 warpedPoint = warped.xy / warped.z;

    outputPoints[id] = warpedPoint;
}
