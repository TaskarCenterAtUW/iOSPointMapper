//
//  CapturedMeshDefinitions.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/27/25.
//
import Foundation
import ARKit

public struct CapturedMeshAnchorSnapshot: Sendable {
    public let vertexData: Data
    public let indexData: Data
    
    public let vertexCount: Int
    public let indexCount: Int
}

public struct CapturedMeshSnapshot: Sendable {
    public let anchors: [AccessibilityFeatureClass: CapturedMeshAnchorSnapshot]
    
    public let vertexStride: Int
    public let vertexOffset: Int
    public let indexStride: Int
    public let classificationStride: Int
    
    public let totalVertexCount: Int
}
