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

struct GrayscaleToColorFilter {
    // Metal-related properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw GrayscaleToColorFilterError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device)
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "colorMatchingKernelLUT"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw GrayscaleToColorFilterError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }

    func apply(to inputImage: CIImage, grayscaleValues: [Float], colorValues: [CIColor]) throws -> CIImage {
        // TODO: Check if descriptor can be added to initializer by saving the input image dimensions as constants
        //  This may be possible since we know that the vision model returns fixed sized images to the segmentation view controller
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        guard let cgImage = self.ciContext.createCGImage(inputImage, from: inputImage.extent) else {
            throw GrayscaleToColorFilterError.invalidInputImage
        }
        
        // TODO: Instead of creating texture from CGImage, try to create from CVPixelBuffer directly
        // As shown in SegmentationMeshRecord.swift
        guard let inputTexture = try? self.textureLoader.newTexture(cgImage: cgImage, options: options) else {
            throw GrayscaleToColorFilterError.textureCreationFailed
        }

        // commandEncoder is used for compute pipeline instead of the traditional render pipeline
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor),
              let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw GrayscaleToColorFilterError.textureCreationFailed
        }
        
        var grayscaleToColorLUT: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0, 0, 0), count: 256)
        for (i, grayscaleValue) in grayscaleValues.enumerated() {
            let index = min(Int((grayscaleValue * 255).rounded()), 255)
            grayscaleToColorLUT[index] = SIMD3<Float>(Float(colorValues[i].red), Float(colorValues[i].green), Float(colorValues[i].blue))
        }
        let grayscaleToColorLUTBuffer = self.device.makeBuffer(bytes: grayscaleToColorLUT, length: grayscaleToColorLUT.count * MemoryLayout<SIMD3<Float>>.size, options: [])
        
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

        guard let resultImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: NSNull()]) else {
            throw GrayscaleToColorFilterError.outputImageCreationFailed
        }
        return resultImage
    }
}
