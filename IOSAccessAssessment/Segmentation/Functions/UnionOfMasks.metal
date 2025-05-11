//
//  UnionOfMasks.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/10/25.
//

#include <metal_stdlib>
using namespace metal;

// Metal has a limit on the number of textures that can be passed to a kernel: 31.
// For this kernel, we will set the maximum number of textures to 16.
kernel
void
unionOfMasksKernel(
    texture2d_array<float, access::read> masks [[texture(0)]],
    texture2d<float, access::write> outputTexture [[texture(16)]],
    constant uint &maskCount [[buffer(0)]],
    constant uint8_t &targetValue [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    
}
