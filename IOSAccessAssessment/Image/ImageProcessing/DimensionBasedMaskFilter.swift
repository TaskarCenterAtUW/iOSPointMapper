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
    case outputImageCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationFailed:
            return "Failed to initialize Metal resources."
        case .invalidInputImage:
            return "The input image is invalid."
        case .textureCreationFailed:
            return "Failed to create Metal textures."
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
              let commandQueue = device.makeCommandQueue() else  {
            throw DimensionBasedMaskFilterError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device)
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "dimensionBasedMaskingKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw DimensionBasedMaskFilterError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }

    func apply(to inputImage: CIImage, bounds: DimensionBasedMaskBounds) throws -> CIImage {
        // TODO: Check if descriptor can be added to initializer by saving the input image dimensions as constants
        //  This may be possible since we know that the vision model returns fixed sized images to the segmentation view controller
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        guard let cgImage = self.ciContext.createCGImage(inputImage, from: inputImage.extent) else {
            throw DimensionBasedMaskFilterError.invalidInputImage
        }
        
        guard let inputTexture = try? self.textureLoader.newTexture(cgImage: cgImage, options: options) else {
            throw DimensionBasedMaskFilterError.textureCreationFailed
        }

        // commandEncoder is used for compute pipeline instead of the traditional render pipeline
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor),
              let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw DimensionBasedMaskFilterError.textureCreationFailed
        }
        
        var minXLocal = bounds.minX
        var maxXLocal = bounds.maxX
        var minYLocal = bounds.minY
        var maxYLocal = bounds.maxY
        
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
            mtlTexture: outputTexture, options: [.colorSpace: CGColorSpaceCreateDeviceGray()]
        ) else {
            throw DimensionBasedMaskFilterError.outputImageCreationFailed
        }
        return resultCIImage
    }
}
