//
//  SegmentationMeshGPUPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//

import SwiftUI
import ARKit
import RealityKit
import simd
import MetalKit

public enum MetalContextError: Error, LocalizedError {
    case metalDeviceUnavailable
    case metalInitializationError
    
    public var errorDescription: String? {
        switch self {
        case .metalDeviceUnavailable:
            return NSLocalizedString("Metal device is unavailable on this device.", comment: "")
        case .metalInitializationError:
            return NSLocalizedString("Failed to initialize Metal for Mesh GPU processing.", comment: "")
        }
    }
}

public final class MetalContext {
    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
//    let pipelineState: MTLComputePipelineState
    public let textureCache: CVMetalTextureCache
    public let textureLoader: MTKTextureLoader
    
    public let ciContext: CIContext
    public let ciContextNoColorSpace: CIContext
    
    public init() throws {
        let device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            throw MetalContextError.metalDeviceUnavailable
        }
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else  {
            throw MetalContextError.metalInitializationError
        }
        self.commandQueue = commandQueue
        
        var metalTextureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &metalTextureCache) == kCVReturnSuccess,
            let textureCache = metalTextureCache
        else {
            throw SegmentationMeshRecordError.metalInitializationError
        }
        self.textureCache = textureCache
        self.textureLoader = MTKTextureLoader(device: device)
        
//        self.context = CIContext(mtlDevice: device, options: [.cvMetalTextureCache: textureCache])
        self.ciContext = CIContext(mtlDevice: device)
        self.ciContextNoColorSpace = CIContext(
            mtlDevice: device,
            options: [CIContextOption.workingColorSpace: NSNull(), CIContextOption.outputColorSpace: NSNull()]
        )
    }
}
