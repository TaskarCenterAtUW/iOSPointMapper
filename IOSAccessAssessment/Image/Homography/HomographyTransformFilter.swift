//
//  HomographyProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/9/25.
//

import UIKit
import Metal
import CoreImage
import MetalKit

enum HomographyTransformFilterError: Error, LocalizedError {
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

struct HomographyTransformFilter {
    // Metal-related properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw HomographyTransformFilterError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device)
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "homographyWarpKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw HomographyTransformFilterError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }
    
    /**
        Applies a homography transformation to the input CIImage using the provided transformation matrix.

        - Parameters:
            - inputImage: The input CIImage to be transformed. Of color space nil, single-channel.
            - transformMatrix: A 3x3 matrix representing the homography transformation.
     */
    func apply(to inputImage: CIImage, transformMatrix: simd_float3x3) throws -> CIImage {
        // TODO: Check if descriptor can be added to initializer by saving the input image dimensions as constants
        //  This may be possible since we know that the vision model returns fixed sized images to the segmentation view controller
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        guard let cgImage = self.ciContext.createCGImage(inputImage, from: inputImage.extent) else {
            throw HomographyTransformFilterError.invalidInputImage
        }
        
        let inputTexture = try self.textureLoader.newTexture(cgImage: cgImage, options: options)
//        guard let inputTexture = self.renderCIImageToTexture(inputImage, on: self.device, context: self.ciContext) else {
//            return nil
//        }

        // commandEncoder is used for compute pipeline instead of the traditional render pipeline
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor),
              let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HomographyTransformFilterError.textureCreationFailed
        }
        
        var transformMatrixLocal = transformMatrix
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.setBytes(&transformMatrixLocal, length: MemoryLayout<simd_float3x3>.size, index: 0)
        
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (Int(inputImage.extent.width) + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (Int(inputImage.extent.height) + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard let resultImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: CGColorSpaceCreateDeviceGray()]) else {
            throw HomographyTransformFilterError.outputImageCreationFailed
        }
        return resultImage
    }
    
//    private func renderCIImageToTexture(_ ciImage: CIImage, on device: MTLDevice, context: CIContext) -> MTLTexture? {
//        let width = Int(ciImage.extent.width)
//        let height = Int(ciImage.extent.height)
//
//        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: width, height: height, mipmapped: false)
//        descriptor.usage = [.shaderRead, .shaderWrite]
//
//        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
//
//        context.render(ciImage, to: texture, commandBuffer: nil, bounds: ciImage.extent, colorSpace: CGColorSpaceCreateDeviceGray())
//        return texture
//    }

}
