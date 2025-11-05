//
//  ShaderTypes.h
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/4/25.
//
#pragma once

#include <simd/simd.h>

#ifdef __METAL_VERSION__
  #include <metal_stdlib>
  using namespace metal;
#else
  #include <simd/simd.h>
  typedef struct { float x, y, z; } packed_float3;
#endif

typedef struct MeshTriangle {
    packed_float3 a;
    packed_float3 b;
    packed_float3 c;
} MeshTriangle;
