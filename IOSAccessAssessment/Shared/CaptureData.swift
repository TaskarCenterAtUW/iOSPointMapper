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
    let segmentedClasses: [AccessibilityFeatureClass]
    let detectedObjectMap: [UUID: DetectedAccessibilityFeature]
    // TODO: A sendable version of segmented mesh records
    // Keep it optional because mesh data does not need to be captured every time
}

struct CaptureData: Sendable, Identifiable {
    let id: UUID
    
    let interfaceOrientation: UIInterfaceOrientation
    let timestamp: TimeInterval
    
    let cameraImage: CIImage
    let depthImage: CIImage
    let confidenceImage: CIImage?
    
    let cameraTransform: simd_float4x4
    let cameraIntrinsics: simd_float3x3
    
    let captureDataResults: CaptureDataResults
}
