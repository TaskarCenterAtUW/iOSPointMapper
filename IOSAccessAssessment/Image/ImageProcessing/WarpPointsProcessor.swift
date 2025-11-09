//
//  BinaryMaskCIFilter.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/17/25.
//


import UIKit
import Metal
import CoreImage
import MetalKit

/**
    A struct that processes warp points using Metal.
    NOTE: This file has been removed from the app. It is only stored currently for reference.
 */
struct WarpPointsProcessor {
    var inputImage: CIImage?
    
    // Metal-related properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState

    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            fatalError("Error: Failed to initialize Metal resources")
        }
        self.device = device
        self.commandQueue = commandQueue
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "binaryMaskingKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            fatalError("Error: Failed to initialize Metal pipeline")
        }
        self.pipeline = pipeline
    }
    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }

    func apply(to inputPoints: [SIMD2<Float>], transformMatrix: simd_float3x3) -> [SIMD2<Float>]? {
        let inputBuffer = device.makeBuffer(bytes: inputPoints,
                                            length: MemoryLayout<SIMD2<Float>>.stride * inputPoints.count,
                                            options: [])

        let outputBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * inputPoints.count,
                                             options: [])
        var transformMatrixLocal = transformMatrix

        guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setBuffer(inputBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(outputBuffer, offset: 0, index: 1)
        commandEncoder.setBytes(&transformMatrixLocal, length: MemoryLayout<simd_float3x3>.size, index: 2)
        
        let threadCount = inputPoints.count
        let threadgroupSize = MTLSize(width: 16, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (threadCount + 15) / 16, height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let outputPointer = outputBuffer?.contents().bindMemory(to: SIMD2<Float>.self, capacity: inputPoints.count)
        guard let outputPointer = outputPointer else {
            return nil
        }
        let outputPoints = Array(UnsafeBufferPointer(start: outputPointer, count: inputPoints.count))
        return outputPoints
    }
}
