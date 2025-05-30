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

    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            fatalError("Error: Failed to initialize Metal resources")
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device)
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "dimensionBasedMaskingKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            fatalError("Error: Failed to initialize Metal pipeline")
        }
        self.pipeline = pipeline
    }
    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }

    func apply(to inputImage: CIImage, bounds: DimensionBasedMaskBounds) -> CIImage? {
        // TODO: Check if descriptor can be added to initializer by saving the input image dimensions as constants
        //  This may be possible since we know that the vision model returns fixed sized images to the segmentation view controller
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        guard let cgImage = self.ciContext.createCGImage(inputImage, from: inputImage.extent) else {
            print("Error: inputImage does not have a valid CGImage")
            return nil
        }
        
        guard let inputTexture = try? self.textureLoader.newTexture(cgImage: cgImage, options: options) else {
            return nil
        }

        // commandEncoder is used for compute pipeline instead of the traditional render pipeline
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor),
              let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
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

        return CIImage(mtlTexture: outputTexture, options: [.colorSpace: CGColorSpaceCreateDeviceGray()])//?.oriented(.downMirrored)
    }
}
