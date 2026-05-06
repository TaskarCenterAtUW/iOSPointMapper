//
//  CenterCropTransformUtils.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/9/26.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;
#import "ShaderTypes.h"

extern "C" kernel void revertCenterCropAspectFitKernel(
   texture2d<float, access::read>  src [[ texture(0) ]],
   texture2d<float, access::write> dst [[ texture(1) ]],
   constant RevertCenterCropParams& params   [[ buffer(0) ]],
   uint2 gid                       [[ thread_position_in_grid ]]
) {
    if (gid.x >= params.dstWidth || gid.y >= params.dstHeight) {
        return;
    }
    // Destination pixel center
    float2 dstPos = float2(gid) + 0.5;
    // Map back to source space
    float2 srcPos = (dstPos - params.offset) / params.scale;
    
    // Nearest-neighbor sampling
    int sx = int(round(srcPos.x - 0.5));
    int sy = int(round(srcPos.y - 0.5));
    
    float4 pixelColor = float4(0.0, 0.0, 0.0, 0.0);
    if (sx >= 0 && sy >= 0 && sx < int(params.srcWidth) && sy < int(params.srcHeight)) {
        pixelColor = src.read(uint2(sx, sy));
    }
    dst.write(pixelColor, gid);
}
