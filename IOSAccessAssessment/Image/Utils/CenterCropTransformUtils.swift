//
//  CenterCropTransformUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/9/26.
//

import Metal
import MetalKit

enum CenterCropTransformUtilsError: Error, LocalizedError {
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

struct CenterCropTransformUtils {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw CenterCropTransformUtilsError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    }
    
    func revertCenterCropAspectFit(_ image: CIImage, to destSize: CGSize) throws -> CIImage {
        let sourceSize = image.extent.size
        let sourceAspect = sourceSize.width / sourceSize.height
        let destAspect = destSize.width / destSize.height
        
        let scale: CGFloat
        var offsetX: CGFloat = 0
        var offsetY: CGFloat = 0
        if sourceAspect < destAspect {
            scale = destSize.height / sourceSize.height
            let scaledWidth = sourceSize.width * scale
            offsetX = (destSize.width - scaledWidth) / 2
        } else {
            scale = destSize.width / sourceSize.width
            let scaledHeight = sourceSize.height * scale
            offsetY = (destSize.height - scaledHeight) / 2
        }
        var params = RevertCenterCropParams(
            srcWidth: UInt32(sourceSize.width),
            srcHeight: UInt32(sourceSize.height),
            dstWidth: UInt32(destSize.width),
            dstHeight: UInt32(destSize.height),
            scale: Float(scale),
            offset: SIMD2<Float>(Float(offsetX), Float(offsetY))
        )
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: Int(destSize.width), height: Int(destSize.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw CenterCropTransformUtilsError.metalPipelineCreationError
        }
        let sourceTexture: MTLTexture = try image.toMTLTexture(
            device: device, commandBuffer: commandBuffer, pixelFormat: .r8Unorm,
            context: ciContext, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        guard let destTexture = self.device.makeTexture(descriptor: descriptor) else {
            throw CenterCropTransformUtilsError.textureCreationFailed
        }
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "revertCenterCropAspectFitKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw CenterCropTransformUtilsError.metalInitializationFailed
        }
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw CenterCropTransformUtilsError.metalPipelineCreationError
        }
        commandEncoder.setComputePipelineState(pipeline)
        commandEncoder.setTexture(sourceTexture, index: 0)
        commandEncoder.setTexture(destTexture, index: 1)
        commandEncoder.setBytes(&params, length: MemoryLayout<RevertCenterCropParams>.stride, index: 0)
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (Int(destSize.width) + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (Int(destSize.height) + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        guard let destCIImage = CIImage(mtlTexture: destTexture, options: [.colorSpace: NSNull()]) else {
            throw CenterCropTransformUtilsError.outputImageCreationFailed
        }
        return destCIImage
    }
}
