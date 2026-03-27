//
//  CapturedMeshDefinitions.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/27/25.
//
import Foundation
import ARKit

struct CapturedMeshAnchorSnapshot: Sendable {
    let vertexData: Data
    let indexData: Data
    
    let vertexCount: Int
    let indexCount: Int
}

struct CapturedMeshSnapshot: Sendable {
    let anchors: [AccessibilityFeatureClass: CapturedMeshAnchorSnapshot]
    
    let vertexStride: Int
    let vertexOffset: Int
    let indexStride: Int
    let classificationStride: Int
    
    let totalVertexCount: Int
}
