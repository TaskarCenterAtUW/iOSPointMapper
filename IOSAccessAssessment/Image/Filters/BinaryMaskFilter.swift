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

enum BinaryMaskFilterError: Error, LocalizedError {
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

struct BinaryMaskFilter {
    // Metal-related properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw BinaryMaskFilterError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device)
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "binaryMaskingKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw BinaryMaskFilterError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }
    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }

    func apply(to inputImage: CIImage, targetValue: UInt8) throws -> CIImage {
        // TODO: Check if descriptor can be added to initializer by saving the input image dimensions as constants
        //  This may be possible since we know that the vision model returns fixed sized images to the segmentation view controller
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        guard let cgImage = self.ciContext.createCGImage(inputImage, from: inputImage.extent) else {
            throw BinaryMaskFilterError.invalidInputImage
        }
        
        let inputTexture = try self.textureLoader.newTexture(cgImage: cgImage, options: options)

        // commandEncoder is used for compute pipeline instead of the traditional render pipeline
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor),
              let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BinaryMaskFilterError.textureCreationFailed
        }
        
        var targetValueLocal = targetValue
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.setBytes(&targetValueLocal, length: MemoryLayout<UInt8>.size, index: 0)
        
//        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (Int(inputImage.extent.width) + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (Int(inputImage.extent.height) + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard let resultCIImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: NSNull()]) else {
            throw BinaryMaskFilterError.outputImageCreationFailed
        }
        return resultCIImage
    }
}
