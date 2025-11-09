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

enum MeshGPUContextError: Error, LocalizedError {
    case metalInitializationError
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationError:
            return NSLocalizedString("Failed to initialize Metal for Mesh GPU processing.", comment: "")
        }
    }
}

final class MeshGPUContext {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
//    let pipelineState: MTLComputePipelineState
    let textureCache: CVMetalTextureCache
    
    let ciContext: CIContext
    let ciContextNoColorSpace: CIContext
    
    init(device: MTLDevice) throws {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else  {
            throw MeshGPUContextError.metalInitializationError
        }
        self.commandQueue = commandQueue
        
//        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "processMesh") else {
//            throw SegmentationMeshGPUPipelineError.metalInitializationError
//        }
//        self.pipelineState = try device.makeComputePipelineState(function: kernelFunction)
        
        var metalTextureCache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &metalTextureCache) == kCVReturnSuccess,
            let textureCache = metalTextureCache
        else {
            throw SegmentationMeshRecordError.metalInitializationError
        }
        self.textureCache = textureCache
        
//        self.context = CIContext(mtlDevice: device, options: [.cvMetalTextureCache: textureCache])
        self.ciContext = CIContext(mtlDevice: device)
        self.ciContextNoColorSpace = CIContext(
            mtlDevice: device,
            options: [CIContextOption.workingColorSpace: NSNull(), CIContextOption.outputColorSpace: NSNull()]
        )
    }
}
