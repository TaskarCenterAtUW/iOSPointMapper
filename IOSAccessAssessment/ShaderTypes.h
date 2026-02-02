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
    typedef uint8_t            MTL_UINT8;     // 8-bit
    typedef uint               MTL_UINT;      // 32-bit
    typedef uint               MTL_BOOL;      // use 0/1
    typedef float2             MTL_FLOAT2;
    typedef float3             MTL_FLOAT3;
    typedef float4x4           MTL_FLOAT4X4;
    typedef float3x3           MTL_FLOAT3X3;  // 48 bytes (3 cols, 16B aligned)
    typedef uint2              MTL_UINT2;
#else
    #include <simd/simd.h>
    #include <Metal/MTLTypes.h>
    typedef struct { float x; float y; float z; } packed_float3;
    typedef uint8_t            MTL_UINT8;     // 8-bit
    typedef uint32_t           MTL_UINT;
    typedef uint32_t           MTL_BOOL;      // 0/1
    typedef simd_float2        MTL_FLOAT2;
    typedef simd_float3        MTL_FLOAT3;
    typedef simd_float4x4      MTL_FLOAT4X4;
    typedef simd_float3x3      MTL_FLOAT3X3;  // 48 bytes
    typedef simd_uint2         MTL_UINT2;
#endif

typedef struct MeshTriangle {
    packed_float3 a;
    packed_float3 b;
    packed_float3 c;
} MeshTriangle;

typedef struct MeshParams {
    MTL_UINT        faceCount;
    MTL_UINT        totalCount;
    MTL_UINT        indicesPerFace;   // 3
    MTL_BOOL        hasClass;         // classificationBuffer bound?
    MTL_FLOAT4X4    anchorTransform;
    MTL_FLOAT4X4    cameraTransform;
    MTL_FLOAT4X4    viewMatrix;
    MTL_FLOAT3X3    intrinsics;
    MTL_UINT2       imageSize;
} MeshParams;

typedef struct AccessibilityFeatureMeshClassificationParams {
    MTL_UINT       classificationLookupTable[256];
    MTL_UINT8      labelValue;
    MTL_UINT8      padding[3]; // for alignment
} SegmentationMeshClassificationParams;

typedef struct BoundsParams {
    float       minX;
    float       minY;
    float       maxX;
    float       maxY;
} BoundsParams;

// For back-projecting pixels to World Points (useful for applications such as plane-fitting)
typedef struct WorldPoint {
    MTL_FLOAT3  p;
} WorldPoint;

typedef struct ProjectedPoint {
    float s;
    float t;
} WorldSTPoint;

typedef struct WorldPointsParams {
    MTL_UINT2       imageSize;
    float           minDepthThreshold;
    float           maxDepthThreshold;
    MTL_FLOAT4X4    cameraTransform;
    MTL_FLOAT3X3    invIntrinsics;
} WorldPointsParams;

typedef struct ProjectedPointsParams {
    MTL_UINT2       imageSize;
    MTL_FLOAT4X4    cameraTransform;
    MTL_FLOAT3X3    cameraIntrinsics;
    MTL_FLOAT3      longitudinalVector;
    MTL_FLOAT3      lateralVector;
    MTL_FLOAT3      normalVector;
    MTL_FLOAT3      origin;
} ProjectedPointsParams;

typedef struct ProjectedPointBinningParams {
    float sMin;
    float sMax;
    float sBinSize;
    MTL_UINT binCount;
    MTL_UINT maxValuesPerBin;
} ProjectedPointBinningParams;
