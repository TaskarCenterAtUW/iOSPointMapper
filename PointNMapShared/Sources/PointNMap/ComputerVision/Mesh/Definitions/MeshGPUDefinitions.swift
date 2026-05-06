//
//  MeshGPUDefinitions.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/27/25.
//
import Foundation
import PointNMapShaderTypes

public struct MeshGPUAnchor {
    public var vertexBuffer: MTLBuffer
    public var indexBuffer: MTLBuffer
    public var classificationBuffer: MTLBuffer? = nil
    public var anchorTransform: simd_float4x4
    public var vertexCount: Int = 0
    public var indexCount: Int = 0
    public var faceCount: Int = 0
    public var generation: Int = 0
}

public struct MeshGPUSnapshot {
    public let vertexStride: Int
    public let vertexOffset: Int
    public let indexStride: Int
    public let classificationStride: Int
    public let anchors: [UUID: MeshGPUAnchor]
}
