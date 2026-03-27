//
//  GrayscaleToColorFilter.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/27/24.
//

import UIKit
import Metal
import CoreImage
import MetalKit

enum GrayscaleToColorFilterError: Error, LocalizedError {
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

struct GrayscaleToColorFilter {
    // Metal-related properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext
    private let outputColorSpace = CGColorSpaceCreateDeviceRGB()

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw GrayscaleToColorFilterError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "colorMatchingKernelLUT"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw GrayscaleToColorFilterError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }

    /**
        Applies the grayscale to color mapping filter to the input CIImage.
     
        - Parameters:
            - inputImage: The input CIImage in grayscale format. Of color space nil, single-channel.
            - grayscaleValues: An array of Float values representing the grayscale levels (0.0 to 1.0).
            - colorValues: An array of CIColor values corresponding to the grayscale levels.
     */
    func apply(to inputImage: CIImage, grayscaleValues: [Float], colorValues: [CIColor]) throws -> CIImage {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw GrayscaleToColorFilterError.metalPipelineCreationError
        }
        
        let inputTexture = try inputImage.toMTLTexture(
            device: self.device, commandBuffer: commandBuffer, pixelFormat: .r8Unorm,
            context: self.ciContext,
            colorSpace: CGColorSpaceCreateDeviceRGB() /// Dummy color space
        )
//        let inputTexture = try inputImage.toMTLTexture(textureLoader: textureLoader, context: ciContext)
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor) else {
            throw GrayscaleToColorFilterError.textureCreationFailed
        }
        
        let grayscaleToColorLUT: [SIMD3<Float>] = self.getGrayscaleToColorLookupTable(
            grayscaleValues: grayscaleValues, colorValues: colorValues
        )
        let grayscaleToColorLUTBuffer = self.device.makeBuffer(bytes: grayscaleToColorLUT, length: grayscaleToColorLUT.count * MemoryLayout<SIMD3<Float>>.size, options: [])
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw GrayscaleToColorFilterError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.setBuffer(grayscaleToColorLUTBuffer, offset: 0, index: 0)
        
//        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (Int(inputImage.extent.width) + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (Int(inputImage.extent.height) + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard let resultImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: outputColorSpace]) else {
            throw GrayscaleToColorFilterError.outputImageCreationFailed
        }
        return resultImage
    }
    
    private func getGrayscaleToColorLookupTable(grayscaleValues: [Float], colorValues: [CIColor]) -> [SIMD3<Float>] {
        var grayscaleToColorLUT: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0, 0, 0), count: 256)
        for (i, grayscaleValue) in grayscaleValues.enumerated() {
            let index = min(Int((grayscaleValue * 255).rounded()), 255)
            grayscaleToColorLUT[index] = SIMD3<Float>(Float(colorValues[i].red), Float(colorValues[i].green), Float(colorValues[i].blue))
        }
        return grayscaleToColorLUT
    }
}
