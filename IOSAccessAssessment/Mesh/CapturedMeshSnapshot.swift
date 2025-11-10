//
//  CapturedMeshSnapshot.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//
import ARKit
import RealityKit

struct CapturedMeshAnchorSnapshot: Sendable {
    let vertexData: Data
    let indexData: Data
    
    let anchorTransform: simd_float4x4
    let vertexCount: Int
    let indexCount: Int
}

struct CapturedMeshSnapshot: Sendable {
    let vertexStride: Int
    let vertexOffset: Int
    let indexStride: Int
    let classificationStride: Int
    let anchors: [AccessibilityFeatureClass: CapturedMeshAnchorSnapshot]
    
    init(
        vertexStride: Int,
        vertexOffset: Int,
        indexStride: Int,
        classificationStride: Int,
        meshGPUAnchors: [AccessibilityFeatureClass: SegmentationMeshRecord]
    ) {
        self.vertexStride = vertexStride
        self.vertexOffset = vertexOffset
        self.indexStride = indexStride
        self.classificationStride = classificationStride
        
        // TODO: Convert SegmentationMeshRecord to CapturedMeshAnchorSnapshot
        self.anchors = [:]
    }
}
