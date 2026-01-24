//
//  DepthFiltering.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/24/26.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;
#import "ShaderTypes.h"

extern "C" kernel void depthFilteringKernel(
    texture2d<float, access::read> inputTexture [[texture(0)]],
    texture2d<float, access::read> depthTexture [[texture(1)]],
    texture2d<float, access::write> outputTexture [[texture(2)]],
    constant float &depthMinThreshold [[buffer(0)]],
    constant float &depthMaxThreshold [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= inputTexture.get_width() || gid.y >= inputTexture.get_height())
        return;
    
    float4 pixelColor = inputTexture.read(gid);
    
    float depthValue = depthTexture.read(gid).r;
    if (depthValue < depthMinThreshold || depthValue > depthMaxThreshold) {
        pixelColor = float4(0.0, 0.0, 0.0, 0.0);
    }
    
    outputTexture.write(pixelColor, gid);
}
    
    
        
