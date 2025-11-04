//
//  MeshGPUPipeline.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//

#include <metal_stdlib>
using namespace metal;

// Face output written by the kernel (one per face)
struct FaceOut {
    float3 centroid;
    float3 normal;
    uchar  cls;     // semantic class, optional
    uchar  visible; // 0/1 (set by your logic)
    ushort _pad;    // pad to 16B alignment (Metal likes 16B alignment)
};

struct FaceParams {
    uint  faceCount;
    uint  indicesPerFace;   // 3
    bool  hasClass;         // classificationBuffer bound?
    float4x4 worldFromLocal; // per-anchor, optional
    float4x4 viewProj;       // optional, for frustum tests
};

kernel void processMesh(
    device const float3* positions      [[ buffer(0) ]],
    device const uint*   indices        [[ buffer(1) ]],
    device const uchar*  classesOpt     [[ buffer(2) ]], // may be null if hasClass == false
    device FaceOut*      outFaces       [[ buffer(3) ]],
    constant FaceParams& P              [[ buffer(4) ]],
    uint tid                             [[ thread_position_in_grid ]]
) {
    if (tid >= P.faceCount) return;

    const uint base = tid * P.indicesPerFace; // 3 per triangle in ARKit
    const uint i0 = indices[base + 0];
    const uint i1 = indices[base + 1];
    const uint i2 = indices[base + 2];

    // Load local-space positions
    float3 p0 = positions[i0];
    float3 p1 = positions[i1];
    float3 p2 = positions[i2];

    // Optional: transform to world space if your positions are anchor-local:
    // float4 w0 = P.worldFromLocal * float4(p0, 1.0);
    // float4 w1 = P.worldFromLocal * float4(p1, 1.0);
    // float4 w2 = P.worldFromLocal * float4(p2, 1.0);
    // p0 = w0.xyz / w0.w; p1 = w1.xyz / w1.w; p2 = w2.xyz / w2.w;

    // Face normal (CCW)
    float3 e1 = p1 - p0;
    float3 e2 = p2 - p0;
    float3 n  = normalize(cross(e1, e2));

    // Centroid
    float3 c = (p0 + p1 + p2) / 3.0f;

    // Optional: quick backface/frustum test to set visible flag
    uchar vis = 1;
    // Example backface to camera test if you have camera position in world:
    // float3 camPos = ... (supply via params if needed)
    // vis = dot(normalize(camPos - c), n) > 0.0f ? 1 : 0;

    // Optional frustum test:
    // float4 clip = P.viewProj * float4(c, 1.0);
    // if (any(abs(clip.xyz) > clip.www)) vis = 0;

    // Classification (per face)
    uchar cls = 255;
    if (P.hasClass && classesOpt != nullptr) {
        cls = classesOpt[tid];
    }

    // Write result
    FaceOut fo;
    fo.centroid = c;
    fo.normal   = n;
    fo.cls      = cls;
    fo.visible  = vis;
    fo._pad     = 0;
    outFaces[tid] = fo;
}
