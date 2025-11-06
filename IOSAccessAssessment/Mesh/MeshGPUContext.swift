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

final class MeshGPUContext {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    
    init(device: MTLDevice) throws {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else  {
            throw SegmentationMeshGPUPipelineError.metalInitializationError
        }
        self.commandQueue = commandQueue
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "processMesh") else {
            throw SegmentationMeshGPUPipelineError.metalInitializationError
        }
        self.pipelineState = try device.makeComputePipelineState(function: kernelFunction)
    }
}
