//
//  Plane.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/2/26.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;
#import "ShaderTypes.h"

kernel void binProjectedPoints(
   device const ProjectedPoint* inputPoints [[buffer(0)]],
   constant uint& pointCount [[buffer(1)]],
   constant ProjectedPointBinningParams& params [[buffer(2)]],
   device atomic_uint* binValueCounts [[buffer(3)]],
   device float* binTValues [[buffer(4)]],
   uint id [[thread_position_in_grid]]
) {
    if (id >= pointCount) return;
    float s = inputPoints[id].s;
    float t = inputPoints[id].t;
    
    // Gate by s limits
    if (s < params.sMin || s > params.sMax) { return; }
    
    uint bin = uint(floor((s - params.sMin) / params.sBinSize));
    if (bin >= params.binCount) { return; }
    
    uint count = atomic_fetch_add_explicit(&binValueCounts[bin], 1u, memory_order_relaxed);
    if (count < params.maxValuesPerBin) {
        binTValues[bin * params.maxValuesPerBin + count] = t;
    }
}
