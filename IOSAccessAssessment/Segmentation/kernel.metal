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
//    constant float* grayscaleValues [[buffer(0)]],
    constant int* grayscaleValues [[buffer(0)]],
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
