//
//  MeshGPUDefinitions.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/27/25.
//
import Foundation

struct MeshGPUAnchor {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var classificationBuffer: MTLBuffer? = nil
    var anchorTransform: simd_float4x4
    var vertexCount: Int = 0
    var indexCount: Int = 0
    var faceCount: Int = 0
    var generation: Int = 0
}

struct MeshGPUSnapshot {
    let vertexStride: Int
    let vertexOffset: Int
    let indexStride: Int
    let classificationStride: Int
    let anchors: [UUID: MeshGPUAnchor]
}
