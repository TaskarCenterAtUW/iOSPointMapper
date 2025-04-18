//
//  GrayscaleToColorCIFilter.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/27/24.
//

import UIKit
import Metal
import CoreImage
import MetalKit

class GrayscaleToColorCIFilter: CIFilter {
    var inputImage: CIImage?
    var grayscaleValues: [Float] = []
    var colorValues: [CIColor] = []
    
    // Metal-related properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            fatalError("Error: Failed to initialize Metal resources")
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device)
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "colorMatchingKernelLUT"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            fatalError("Error: Failed to initialize Metal pipeline")
        }
        self.pipeline = pipeline
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var outputImage: CIImage? {
        guard let inputImage = inputImage else { return nil }
        return applyFilter(to: inputImage)
    }

    private func applyFilter(to inputImage: CIImage) -> CIImage? {
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

        return CIImage(mtlTexture: outputTexture, options: [.colorSpace: NSNull()])?.oriented(.downMirrored)
    }
}
