//
//  CaptureData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import SwiftUI
import DequeModule
import simd

struct CaptureImageDataResults: Sendable {
    let segmentationLabelImage: CIImage
    let segmentedClasses: [AccessibilityFeatureClass]
    let detectedObjectMap: [UUID: DetectedAccessibilityFeature]
}

struct CaptureMeshDataResults: Sendable {
    let segmentedMesh: CapturedMeshSnapshot
}

/**
 A Protocol defining the common properties for capture data.
 
 NOTE: This protocol is designed to prevent over-dependence on mesh data in scenarios where LIDAR is unavailable or ARKit fails to provide mesh data.
 */
protocol CaptureDataProtocol: Sendable, Identifiable {
    var id: UUID { get }
    var timestamp: TimeInterval { get }
    var cameraImage: CIImage { get }
    var cameraTransform: simd_float4x4 { get }
    var cameraIntrinsics: simd_float3x3 { get }
    var interfaceOrientation: UIInterfaceOrientation { get }
    var originalSize: CGSize { get }
    // MARK: Depth Image should not be optional regardless of LIDAR availability
    // Once the depth model is set up, mark this as non-optional
    var depthImage: CIImage? { get }
    var confidenceImage: CIImage? { get }
}

protocol CaptureImageDataProtocol: CaptureDataProtocol {
    var captureImageDataResults: CaptureImageDataResults { get }
}

protocol CaptureMeshDataProtocol: CaptureDataProtocol {
    var captureMeshDataResults: CaptureMeshDataResults { get }
}

struct CaptureImageData: CaptureImageDataProtocol {
    let id: UUID
    let timestamp: TimeInterval
    
    let cameraImage: CIImage
    let cameraTransform: simd_float4x4
    let cameraIntrinsics: simd_float3x3
    
    let interfaceOrientation: UIInterfaceOrientation
    let originalSize: CGSize
    
    let depthImage: CIImage?
    let confidenceImage: CIImage?
    
    let captureImageDataResults: CaptureImageDataResults
}

struct CaptureAllData: CaptureImageDataProtocol, CaptureMeshDataProtocol {
    let id: UUID
    let timestamp: TimeInterval
    
    let cameraImage: CIImage
    let cameraTransform: simd_float4x4
    let cameraIntrinsics: simd_float3x3
    
    let interfaceOrientation: UIInterfaceOrientation
    let originalSize: CGSize
    
    let depthImage: CIImage?
    let confidenceImage: CIImage?
    
    let captureImageDataResults: CaptureImageDataResults
    let captureMeshDataResults: CaptureMeshDataResults
    
    init(
        id: UUID, timestamp: TimeInterval,
        cameraImage: CIImage, cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        interfaceOrientation: UIInterfaceOrientation, originalSize: CGSize,
        depthImage: CIImage?, confidenceImage: CIImage?,
        captureImageDataResults: CaptureImageDataResults,
        captureMeshDataResults: CaptureMeshDataResults
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cameraImage = cameraImage
        self.cameraTransform = cameraTransform
        self.cameraIntrinsics = cameraIntrinsics
        self.interfaceOrientation = interfaceOrientation
        self.originalSize = originalSize
        self.depthImage = depthImage
        self.confidenceImage = confidenceImage
        self.captureImageDataResults = captureImageDataResults
        self.captureMeshDataResults = captureMeshDataResults
    }
    
    init(captureImageData: CaptureImageData, captureMeshDataResults: CaptureMeshDataResults) {
        self.id = captureImageData.id
        self.timestamp = captureImageData.timestamp
        self.cameraImage = captureImageData.cameraImage
        self.cameraTransform = captureImageData.cameraTransform
        self.cameraIntrinsics = captureImageData.cameraIntrinsics
        self.interfaceOrientation = captureImageData.interfaceOrientation
        self.originalSize = captureImageData.originalSize
        self.depthImage = captureImageData.depthImage
        self.confidenceImage = captureImageData.confidenceImage
        self.captureImageDataResults = captureImageData.captureImageDataResults
        self.captureMeshDataResults = captureMeshDataResults
    }
}
