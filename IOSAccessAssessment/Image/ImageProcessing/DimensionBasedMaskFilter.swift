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

enum DimensionBasedMaskFilterError: Error, LocalizedError {
    case metalInitializationFailed
    case invalidInputImage
    case textureCreationFailed
    case metalPipelineCreationError
    case outputImageCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationFailed:
            return "Failed to initialize Metal resources."
        case .invalidInputImage:
            return "The input image is invalid."
        case .textureCreationFailed:
            return "Failed to create Metal textures."
        case .metalPipelineCreationError:
            return "Failed to create Metal compute pipeline."
        case .outputImageCreationFailed:
            return "Failed to create output CIImage from Metal texture."
        }
    }
}


/**
    A struct that applies a binary mask to an image using Metal.
    The mask is applied based on a target value and specified bounds.
 */
struct DimensionBasedMaskFilter {
    // Metal-related properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw DimensionBasedMaskFilterError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "dimensionBasedMaskingKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw DimensionBasedMaskFilterError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }

    func apply(to inputImage: CIImage, bounds: DimensionBasedMaskBounds) throws -> CIImage {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw DimensionBasedMaskFilterError.metalPipelineCreationError
        }
        
        let inputTexture = try inputImage.toMTLTexture(
            device: self.device, commandBuffer: commandBuffer, pixelFormat: .r8Unorm,
            context: self.ciContext,
            colorSpace: CGColorSpaceCreateDeviceRGB() /// Dummy color space
        )
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor) else {
            throw DimensionBasedMaskFilterError.textureCreationFailed
        }
        var minXLocal = bounds.minX
        var maxXLocal = bounds.maxX
        var minYLocal = bounds.minY
        var maxYLocal = bounds.maxY
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw DimensionBasedMaskFilterError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.setBytes(&minXLocal, length: MemoryLayout<Float>.size, index: 0)
        commandEncoder.setBytes(&maxXLocal, length: MemoryLayout<Float>.size, index: 1)
        commandEncoder.setBytes(&minYLocal, length: MemoryLayout<Float>.size, index: 2)
        commandEncoder.setBytes(&maxYLocal, length: MemoryLayout<Float>.size, index: 3)
        
//        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (Int(inputImage.extent.width) + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (Int(inputImage.extent.height) + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard let resultCIImage = CIImage(
            mtlTexture: outputTexture, options: [.colorSpace: NSNull()]
        ) else {
            throw DimensionBasedMaskFilterError.outputImageCreationFailed
        }
        return resultCIImage
    }
}
