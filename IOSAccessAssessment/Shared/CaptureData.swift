//
//  CaptureData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import SwiftUI
import DequeModule
import simd

struct CaptureDataResults: Sendable {
    let segmentationLabelImage: CIImage
    let segmentationCroppedSize: CGSize
    let segmentedClasses: [AccessibilityFeatureClass]
    let detectedObjectMap: [UUID: DetectedAccessibilityFeature]
    let segmentedMesh: CapturedMeshSnapshot
}

struct CaptureData: Sendable, Identifiable {
    let id: UUID
    
    let timestamp: TimeInterval
    
    let cameraImage: CIImage
    // MARK: Depth Image should not be optional regardless of LIDAR availability
    // Once the depth model is set up, mark this as non-optional
    let depthImage: CIImage?
    let confidenceImage: CIImage?
    
    let cameraTransform: simd_float4x4
    let cameraIntrinsics: simd_float3x3
    
    let interfaceOrientation: UIInterfaceOrientation
    let originalSize: CGSize
    
    let captureDataResults: CaptureDataResults
}
