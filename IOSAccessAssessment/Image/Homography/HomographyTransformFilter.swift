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
    HomographyTransformFilter is a class that applies a homography transformation to a CIImage using Metal.
 */
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
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
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
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw GrayscaleToColorFilterError.metalPipelineCreationError
        }
        
        let inputTexture = try inputImage.toMTLTexture(
            device: self.device, commandBuffer: commandBuffer, pixelFormat: .r8Unorm,
            context: self.ciContext,
            colorSpace: CGColorSpaceCreateDeviceRGB(), /// Dummy color space
            cIImageToMTLTextureOrientation: .metalTopLeft
        )
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor) else {
            throw HomographyTransformFilterError.textureCreationFailed
        }
        var transformMatrixLocal = transformMatrix
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw HomographyTransformFilterError.metalPipelineCreationError
        }
        
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

        guard let resultImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: NSNull()]) else {
            throw HomographyTransformFilterError.outputImageCreationFailed
        }
        let resultImageOriented = resultImage
            .transformed(by: CGAffineTransform(scaleX: 1, y: -1))
            .transformed(by: CGAffineTransform(translationX: 0, y: resultImage.extent.height))
        return resultImageOriented
    }
}
