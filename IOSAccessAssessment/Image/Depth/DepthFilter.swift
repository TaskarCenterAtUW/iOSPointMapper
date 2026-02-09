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
import CoreVideo

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
    private let outputColorSpace: CGColorSpace? = nil //CGColorSpace(name: CGColorSpace.linearGray)
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw DepthFilterError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "depthFilteringKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw DepthFilterError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }
    
    func apply(
        to inputImage: CIImage, depthImage: CIImage,
        depthMinThreshold: Float, depthMaxThreshold: Float
    ) throws -> CIImage {
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
        let depthTexture = try depthImage.toMTLTexture(
            device: self.device, commandBuffer: commandBuffer, pixelFormat: .r32Float,
            context: self.ciContext,
            colorSpace: CGColorSpaceCreateDeviceRGB() /// Dummy color space
        )
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor) else {
            throw DepthFilterError.textureCreationFailed
        }
        var depthMinThresholdVar = depthMinThreshold
        var depthMaxThresholdVar = depthMaxThreshold
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw DepthFilterError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(depthTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        commandEncoder.setBytes(&depthMinThresholdVar, length: MemoryLayout<Float>.size, index: 0)
        commandEncoder.setBytes(&depthMaxThresholdVar, length: MemoryLayout<Float>.size, index: 1)
        
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (Int(inputImage.extent.width) + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (Int(inputImage.extent.height) + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        guard let resultCIImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: outputColorSpace ?? NSNull()]) else {
            throw DepthFilterError.outputImageCreationFailed
        }
        
//        try debugWithPixelBuffer(mtlTexture: outputTexture)
//        try debugWithTransformedCIImage(mtlTexture: outputTexture)
//        try debugWithRevertedCenterCropCIImage(mtlTexture: outputTexture)
        try debugWithSyntheticMaskPixelBuffer()
        try debugWithSyntheticMaskMetal()
        
        return resultCIImage
    }
    
    private func debugWithPixelBuffer(mtlTexture: MTLTexture) throws {
        let pixelBuffer = CVPixelBufferUtils.createPixelBuffer(width: mtlTexture.width, height: mtlTexture.height, pixelFormat: kCVPixelFormatType_OneComponent8)!
        var textureCache: CVMetalTextureCache!
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        var cvMetalTex: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            .r8Unorm,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            0,
            &cvMetalTex
        )
        let dstTexture = CVMetalTextureGetTexture(cvMetalTex!)!
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        let debugKernelFunction = device.makeDefaultLibrary()!.makeFunction(name: "copyMask")!
        let debugPipeline = try device.makeComputePipelineState(function: debugKernelFunction)
        commandEncoder.setComputePipelineState(debugPipeline)
        commandEncoder.setTexture(mtlTexture, index: 0)
        commandEncoder.setTexture(dstTexture, index: 1)
        let threadgroupSize = MTLSize(width: debugPipeline.threadExecutionWidth, height: debugPipeline.maxTotalThreadsPerThreadgroup / debugPipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (mtlTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                      height: (mtlTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                        depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        /// Compare values in the pixel buffer to the output texture to verify that the filtering is working as expected.
        CVMetalTextureCacheFlush(textureCache, 0)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let ptr = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        print("Debugging with Pixel Buffer:")
        print(ptr[0], ptr[10], ptr[100])
    }
    
    private func debugWithTransformedCIImage(mtlTexture: MTLTexture) throws {
        let originalImage = CIImage(mtlTexture: mtlTexture, options: [.colorSpace: NSNull()])!
        let identityTransform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        let ciImage = originalImage.transformed(by: identityTransform)
        
        let rawContext = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        let colorSpace: CGColorSpace? = nil
        let canvas: CGRect = CGRect(x: 0, y: 0, width: ciImage.extent.width, height: ciImage.extent.height)
        
        let pixelBuffer = CVPixelBufferUtils.createPixelBuffer(width: mtlTexture.width, height: mtlTexture.height, pixelFormat: kCVPixelFormatType_OneComponent8)!
        rawContext.render(ciImage, to: pixelBuffer, bounds: canvas, colorSpace: colorSpace)
        
        /// Compare values in the pixel buffer to the output to verify that the filtering is working as expected.
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let ptr = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        print("Debugging with CIImage Rendered Pixel Buffer:")
        print(ptr[0], ptr[10], ptr[100])
    }
    
    private func debugWithRevertedCenterCropCIImage(mtlTexture: MTLTexture) throws {
        let originalImage = CIImage(mtlTexture: mtlTexture, options: [.colorSpace: NSNull()])!
        let rawContext = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        let colorSpace: CGColorSpace? = nil
        
        let pixelBuffer = CVPixelBufferUtils.createPixelBuffer(width: mtlTexture.width, height: mtlTexture.height, pixelFormat: kCVPixelFormatType_OneComponent8)!
        
        CenterCropTransformUtils.revertCenterCropAspectFit(
            originalImage, from: CGSize(width: mtlTexture.width*2, height: mtlTexture.height*2),
            to: pixelBuffer, context: rawContext, colorSpace: colorSpace
        )
        
        /// Compare values in the pixel buffer to the output to verify that the filtering is working as expected.
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let ptr = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        print("Debugging with CIImage Rendered Pixel Buffer 2:")
        print(ptr[0], ptr[10], ptr[100])
    }
    
    private func debugWithSyntheticMaskPixelBuffer() throws {
        let width = 256
        let height = 256
        let pixelBuffer = CVPixelBufferUtils.createPixelBuffer(width: width, height: height, pixelFormat: kCVPixelFormatType_OneComponent8)!
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let ptr = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        for y in 0..<height {
            for x in 0..<width {
                ptr[y * bytesPerRow + x] = UInt8(x % 16)  // values 0–15
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let ptr2 = CVPixelBufferGetBaseAddress(pixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        print("Debugging with Synthetic Mask Pixel Buffer (Direct Access):")
        print(ptr2[0], ptr2[1], ptr2[2], ptr2[8], ptr2[9], ptr2[15])
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        /// Render ciImage to a new pixel buffer to verify that the rendering is working as expected.
        let outputPixelBuffer = CVPixelBufferUtils.createPixelBuffer(width: width, height: height, pixelFormat: kCVPixelFormatType_OneComponent8)!
        let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        context.render(ciImage, to: outputPixelBuffer, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: nil)
        CVPixelBufferLockBaseAddress(outputPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(outputPixelBuffer, .readOnly) }
        let outputPtr = CVPixelBufferGetBaseAddress(outputPixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        print("Debugging with Synthetic Mask Pixel Buffer:")
        print(outputPtr[0], outputPtr[1], outputPtr[2], outputPtr[8], outputPtr[9], outputPtr[15])
    }
    
    private func debugWithSyntheticMaskMetal() throws {
        let width = 256
        let height = 256
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm, width: width, height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let texture = self.device.makeTexture(descriptor: descriptor) else {
            throw DepthFilterError.textureCreationFailed
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()!
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
        let debugKernelFunction = device.makeDefaultLibrary()!.makeFunction(name: "syntheticMask")!
        let debugPipeline = try device.makeComputePipelineState(function: debugKernelFunction)
        commandEncoder.setComputePipelineState(debugPipeline)
        commandEncoder.setTexture(texture, index: 0)
        let threadgroupSize = MTLSize(width: debugPipeline.threadExecutionWidth, height: debugPipeline.maxTotalThreadsPerThreadgroup / debugPipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (texture.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                        height: (texture.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                        depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let ciImage = CIImage(mtlTexture: texture, options: [.colorSpace: NSNull()])!
        /// Render to a pixel buffer to verify that the synthetic mask is being generated as expected.
        let outputPixelBuffer = CVPixelBufferUtils.createPixelBuffer(
            width: width, height: height,
            pixelFormat: kCVPixelFormatType_OneComponent8
        )!
        let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        context.render(ciImage, to: outputPixelBuffer, bounds: CGRect(x: 0, y: 0, width: width, height: height),
                       colorSpace: nil)
        CVPixelBufferLockBaseAddress(outputPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(outputPixelBuffer, .readOnly) }
        let outputPtr = CVPixelBufferGetBaseAddress(outputPixelBuffer)!.assumingMemoryBound(to: UInt8.self)
        print("Debugging with Synthetic Mask Generated by Metal:")
        print(outputPtr[0], outputPtr[1], outputPtr[2], outputPtr[8], outputPtr[9], outputPtr[15])
    }
}
