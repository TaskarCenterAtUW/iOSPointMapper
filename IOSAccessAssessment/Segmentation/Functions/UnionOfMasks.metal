//
//  UnionOfMasks.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/10/25.
//

#include <metal_stdlib>
using namespace metal;

kernel
void
unionOfMasksKernel(
    texture2d_array<float, access::read> masks [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(1)]],
    constant uint &maskCount [[buffer(0)]],
    constant uint8_t &targetValue [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height())
        return;
    
    float4 color = float4(0.0, 0.0, 0.0, 0.0); // Default color
    
    for (uint i = 0; i < maskCount; i++) {
        float4 maskValue = masks.read(gid, i);
        uint8_t index = min(uint(round(maskValue.r * 255.0)), 255u);
        if (index == targetValue) {
            color = maskValue;
            break;
        }
    }
    
    outputTexture.write(color, gid);
}
