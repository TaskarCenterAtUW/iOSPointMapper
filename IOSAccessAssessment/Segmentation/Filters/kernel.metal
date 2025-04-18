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

