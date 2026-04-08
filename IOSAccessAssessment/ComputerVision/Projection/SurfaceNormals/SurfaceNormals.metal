//
//  SurfaceNormals.metal
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/6/26.
//

#include <metal_stdlib>
#include <CoreImage/CoreImage.h>
using namespace metal;
#import "ShaderTypes.h"

inline float2 normalize2D(float2 v) {
    float v_length = length(v);
    return (v_length > 0) ? (v / v_length) : float2(0.0, 0.0);
}

inline float2 makeStep(float2 direction) {
    float maxComp = max(abs(direction.x), abs(direction.y));
    if (maxComp == 0.0) {
        return float2(0.0, 0.0);
    }
    return direction / maxComp;
}

typedef struct OptionalNeighbor {
    float3 neighborPoint;
    bool isValid;
} OptionalNeighbor;

inline OptionalNeighbor walkDirection(
    uint startX, uint startY, float2 step, float sign,
    uint minStep, uint maxStep,
    uint width, uint height,
    device const WorldPointGridCell* grid
) {
    float2 pos = float2(float(startX), float(startY));
    float3 pointSum = float3(0.0);
    float weightSum = 0.0;
    
    for (uint i = minStep; i <= maxStep; i++) {
        pos += step * sign;
        uint xi = uint(round(pos.x));
        uint yi = uint(round(pos.y));
        
        if (xi < 0 || xi >= width || yi < 0 || yi >= height) {
            break; // Out of bounds
        }
        
        uint index = yi * width + xi;
        WorldPointGridCell cell = grid[index];
        if (cell.isValid == 0) {
            continue; // Skip invalid cells
        }
        float weight = 1.0 / i; // Closer neighbors have more weight
        pointSum += cell.worldPoint.p * weight;
        weightSum += weight;
    }
    
    if (weightSum > 0.0) {
        return { pointSum / weightSum, true };
    } else {
        return { float3(0.0), false };
    }
}

inline float3 alignNormalWithReference(float3 normal, float3 reference) {
    if (dot(normal, reference) < 0.0) {
        return -normal;
    }
    return normal;
}

kernel void computeSurfaceNormals(
    device const WorldPointGridCell* inputPoints [[buffer(0)]],
    constant uint& width [[buffer(1)]],
    constant uint& height [[buffer(2)]],
    constant SurfaceNormalForPointGridParams& params [[buffer(3)]],
    device SurfaceNormalForPointGridCell* outputGrid [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    // Index = y * width + x
    uint x = id % width;
    uint y = id / width;
    if (x >= width || y >= height) return;
    
    WorldPointGridCell cell = inputPoints[id];
    if (cell.isValid == 0) {
        return;
    }
    OptionalNeighbor pLPlusOpt = walkDirection(x, y, params.stepL, 1, params.minStep, params.maxStep, width, height, inputPoints);
    if (pLPlusOpt.isValid == 0) {
        return; // Cannot compute normal without a valid neighbor in the positive longitudinal direction
    }
    float3 pLPlus = pLPlusOpt.neighborPoint;
    OptionalNeighbor pLMinusOpt = walkDirection(x, y, params.stepL, -1, params.minStep, params.maxStep, width, height, inputPoints);
    if (pLMinusOpt.isValid == 0) {
        return; // Cannot compute normal without a valid neighbor in the negative longitudinal direction
    }
    float3 pLMinus = pLMinusOpt.neighborPoint;
    OptionalNeighbor pTPlusOpt = walkDirection(x, y, params.stepT, 1, params.minStep, params.maxStep, width, height, inputPoints);
    if (pTPlusOpt.isValid == 0) {
        return; // Cannot compute normal without a valid neighbor in the positive lateral direction
    }
    float3 pTPlus = pTPlusOpt.neighborPoint;
    OptionalNeighbor pTMinusOpt = walkDirection(x, y, params.stepT, -1, params.minStep, params.maxStep, width, height, inputPoints);
    if (pTMinusOpt.isValid == 0) {
        return; // Cannot compute normal without a valid neighbor in the negative lateral direction
    }
    float3 pTMinus = pTMinusOpt.neighborPoint;
    
    float3 longitudinalVector = pLPlus - pLMinus;
    float3 lateralVector = pTPlus - pTMinus;
    
    float longitudinalLength2 = length_squared(longitudinalVector);
    float lateralLength2 = length_squared(lateralVector);
    if (longitudinalLength2 < params.eps || lateralLength2 < params.eps) {
        return; // Cannot compute normal if either vector is too short
    }
    
    float3 normal = cross(longitudinalVector, lateralVector);
    float normalLength2 = length_squared(normal);
    float sinSq = normalLength2 / (longitudinalLength2 * lateralLength2);
    if (sinSq < params.eps) {
        return; // Cannot compute normal if the angle between vectors is too small
    }
    normal = alignNormalWithReference(normal, params.normalVector);
    normal = normalize(normal);
    outputGrid[id].worldPoint = cell.worldPoint;
    outputGrid[id].surfaceNormal = normal;
    outputGrid[id].isValid = true;
}

inline float2 unprojectWorldToPixel(
    float3 worldPoint,
    constant float4x4& viewMatrix,
    constant float3x3& cameraIntrinsics,
    constant uint2& imageSize
) {
    float4 worldPoint4 = float4(worldPoint, 1.0);
    float4 clipSpacePoint = viewMatrix * worldPoint4;
    
    // Ensure z is negative
    if (clipSpacePoint.z > 0) {
        return float2(-1.0, -1.0); // Invalid projection
    }
    
    // Normalized image coordinates (flip y to match image coordinate system)
    float ndcX = clipSpacePoint.x / (-clipSpacePoint.z);
    float ndcY = -clipSpacePoint.y / (-clipSpacePoint.z);
    
    float3 ndcPoint = float3(ndcX, ndcY, 1.0);
    float3 imagePoint = cameraIntrinsics * ndcPoint;
    float2 pixelCoord = imagePoint.xy / imagePoint.z;
    
    return pixelCoord;
}

kernel void getSurfaceNormalsWithinBounds(
    device const SurfaceNormalForPointGridCell* inputGrid [[buffer(0)]],
    constant BoundsParams* boxes [[buffer(1)]],
    constant SurfaceNormalsWithinBoundsParams& params [[buffer(2)]],
    device SurfaceNormalForPointGridCell* outputBoxGrids [[buffer(3)]],
    uint id [[thread_position_in_grid]]
) {
    uint gridCellCount = params.gridWidth * params.gridHeight;
    if (id >= gridCellCount) {
        return;
    }
    SurfaceNormalForPointGridCell cell = inputGrid[id];
    if (cell.isValid == 0) {
        return;
    }
    
    float2 pixelPoint = unprojectWorldToPixel(
        cell.worldPoint.p, params.viewMatrix,
        params.cameraIntrinsics, params.imageSize
    );
    if (!isfinite(pixelPoint.x) || !isfinite(pixelPoint.y)) {
        return;
    }
    uint pixelX = uint(floor(pixelPoint.x));
    uint pixelY = uint(floor(pixelPoint.y));
    if (pixelX < 0 || pixelY < 0 || pixelX >= uint(params.imageSize.x) || pixelY >= uint(params.imageSize.y)) {
        return;
    }
    
    for (uint boxIndex = 0; boxIndex < params.boxCount; ++boxIndex) {
        BoundsParams box = boxes[boxIndex];
        if (pixelX < uint(box.minX) || pixelX > uint(box.maxX) ||
            pixelY < uint(box.minY) || pixelY > uint(box.maxY)) {
            continue;
        }
        uint outputIndex = boxIndex * gridCellCount + pixelY * params.gridWidth + pixelX;
        outputBoxGrids[outputIndex] = cell;
    }
}
