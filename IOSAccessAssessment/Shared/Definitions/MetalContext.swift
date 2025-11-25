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

enum MetalContextError: Error, LocalizedError {
    case metalInitializationError
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationError:
            return NSLocalizedString("Failed to initialize Metal for Mesh GPU processing.", comment: "")
        }
    }
}

final class MetalContext {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
//    let pipelineState: MTLComputePipelineState
    let textureCache: CVMetalTextureCache
    let textureLoader: MTKTextureLoader
    
    let ciContext: CIContext
    let ciContextNoColorSpace: CIContext
    
    init(device: MTLDevice) throws {
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
