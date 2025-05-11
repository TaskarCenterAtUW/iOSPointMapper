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
//    texture2d_array<float, access::read> masks [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(0)]],
    constant uint &maskCount [[buffer(0)]],
    constant uint8_t &targetValue [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height())
        return;
    
    constexpr sampler s(address::clamp_to_edge, filter::nearest);
    
    float2 texCoord = float2(gid) / float2(outputTexture.get_width(), outputTexture.get_height());
    
    float4 color = float4(0.705882352941176, 0.705882352941176, 0.705882352941176, 1.0);
    
    outputTexture.write(color, gid);
}
