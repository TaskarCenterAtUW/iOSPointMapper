//
//  CaptureData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import SwiftUI
import simd
import ARKit

public struct CaptureImageDataResults: Sendable {
    public let segmentationLabelImage: CIImage
    public let segmentedClasses: [AccessibilityFeatureClass]
    /// Map of detected accessibility features with their UUIDs. Not currently used but reserved for potential future use.
    public let detectedFeatureMap: [UUID: DetectedAccessibilityFeature]
}

public struct CaptureMeshDataResults: Sendable {
    public let segmentedMesh: CapturedMeshSnapshot
    public let meshAnchors: [ARMeshAnchor]?
    
    public init(segmentedMesh: CapturedMeshSnapshot, meshAnchors: [ARMeshAnchor]? = nil) {
        self.segmentedMesh = segmentedMesh
        self.meshAnchors = meshAnchors
    }
}

/**
 A Protocol defining the common properties for capture data.
 
 NOTE: This protocol is designed to prevent over-dependence on mesh data in scenarios where LIDAR is unavailable or ARKit fails to provide mesh data.
 */
public protocol CaptureDataProtocol: Sendable, Identifiable {
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

public protocol CaptureImageDataProtocol: CaptureDataProtocol {
    var captureImageDataResults: CaptureImageDataResults { get }
}

public protocol CaptureMeshDataProtocol: CaptureDataProtocol {
    var captureMeshDataResults: CaptureMeshDataResults { get }
}

public struct CaptureImageData: CaptureImageDataProtocol {
    public let id: UUID
    public let timestamp: TimeInterval
    
    public let cameraImage: CIImage
    public let cameraTransform: simd_float4x4
    public let cameraIntrinsics: simd_float3x3
    
    public let interfaceOrientation: UIInterfaceOrientation
    public let originalSize: CGSize
    
    public let depthImage: CIImage?
    public let confidenceImage: CIImage?
    
    public let captureImageDataResults: CaptureImageDataResults
    
    public init(
        id: UUID, timestamp: TimeInterval,
        cameraImage: CIImage, cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        interfaceOrientation: UIInterfaceOrientation, originalSize: CGSize,
        depthImage: CIImage?, confidenceImage: CIImage?,
        captureImageDataResults: CaptureImageDataResults
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
    }
    
    public init(_ captureImageData: (any CaptureImageDataProtocol)) {
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
    }
}

public struct CaptureImageAndMeshData: CaptureImageDataProtocol, CaptureMeshDataProtocol {
    public let id: UUID
    public let timestamp: TimeInterval
    
    public let cameraImage: CIImage
    public let cameraTransform: simd_float4x4
    public let cameraIntrinsics: simd_float3x3
    
    public let interfaceOrientation: UIInterfaceOrientation
    public let originalSize: CGSize
    
    public let depthImage: CIImage?
    public let confidenceImage: CIImage?
    
    public let captureImageDataResults: CaptureImageDataResults
    public let captureMeshDataResults: CaptureMeshDataResults
    
    public init(
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
    
    public init(captureImageData: CaptureImageData, captureMeshDataResults: CaptureMeshDataResults) {
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

/**
 We need a type wrapper that can conditionally represent one of CaptureImageData, CaptureImageAndMeshData, etc.
 */
public enum CaptureData: Sendable, Identifiable {
    case imageData(CaptureImageData)
    case imageAndMeshData(CaptureImageAndMeshData)
    
    public var id: UUID {
        switch self {
        case .imageData(let data):
            return data.id
        case .imageAndMeshData(let data):
            return data.id
        }
    }
    
    public var imageData: any CaptureImageDataProtocol {
        switch self {
        case .imageData(let data):
            return data
        case .imageAndMeshData(let data):
            return CaptureImageData(data)
        }
    }
    
    public var meshData: (any CaptureMeshDataProtocol)? {
        switch self {
        case .imageData(_):
            return nil
        case .imageAndMeshData(let data):
            return data
        }
    }
}

