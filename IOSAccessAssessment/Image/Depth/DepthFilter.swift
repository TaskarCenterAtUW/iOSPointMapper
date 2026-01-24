//
//  DepthFilter.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/24/26.
//

import UIKit
import Metal
import CoreImage
import MetalKit

enum DepthFilterError: Error, LocalizedError {
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
    DepthFilter applies depth-based filtering to images using Metal.
 */
struct DepthFilter {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw DepthFilterError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "depthFilteringKernel"), /// Need to create this kernel
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw BinaryMaskFilterError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }
    
    func apply(to inputImage: CIImage, depthMap: CIImage) throws -> CIImage {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw DepthFilterError.metalPipelineCreationError
        }
        
        let inputTexture = try inputImage.toMTLTexture(
            device: self.device, commandBuffer: commandBuffer, pixelFormat: .r8Unorm,
            context: self.ciContext,
            colorSpace: CGColorSpaceCreateDeviceRGB() /// Dummy color space
        )
        let depthTexture = try depthMap.toMTLTexture(
            device: self.device, commandBuffer: commandBuffer, pixelFormat: .r8Unorm,
            context: self.ciContext,
            colorSpace: CGColorSpaceCreateDeviceRGB() /// Dummy color space
        )
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor) else {
            throw BinaryMaskFilterError.textureCreationFailed
        }
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BinaryMaskFilterError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(depthTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (Int(inputImage.extent.width) + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (Int(inputImage.extent.height) + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        guard let resultCIImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: NSNull()]) else {
            throw DepthFilterError.outputImageCreationFailed
        }
        return resultCIImage
    }
}
