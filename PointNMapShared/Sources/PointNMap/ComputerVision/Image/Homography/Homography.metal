//
//  Homography.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/9/25.
//

#include <metal_stdlib>
using namespace metal;

kernel void homographyWarpKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant float3x3& transformMatrix [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    float2 outputCoord = float2(gid);
    
    float3 pos = float3(outputCoord, 1.0);
    float3 warped = transformMatrix * pos;
    float2 pixelCoord = warped.xy / warped.z;
    
    float2 inputImageSize = float2(inputTexture.get_width(), inputTexture.get_height());

//    float4 color = float4(pixelCoord.x, pixelCoord.y, 0.0, 1.0);
    float4 color = float4(0.0, 0.0, 0.0, 0.0); // Default color
    
    if (all(pixelCoord >= float2(0.0)) && all(pixelCoord < inputImageSize)) {
        // Only read if inside bounds
        float4 colorValue = inputTexture.read(uint2(pixelCoord));
//        color = float4(colorValue, colorValue, colorValue, 1.0);
        color = colorValue;
    }

    outputTexture.write(color, gid);
}
