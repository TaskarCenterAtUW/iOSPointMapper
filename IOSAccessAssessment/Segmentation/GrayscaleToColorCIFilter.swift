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
    private let ciContext: CIContext
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader

    override init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            fatalError("Error: Failed to initialize Metal resources")
        }
        self.device = device
        self.commandQueue = commandQueue
        self.ciContext = CIContext(mtlDevice: device)
        self.textureLoader = MTKTextureLoader(device: device)
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "colorMatchingKernel"),
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
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        let textureLoader = MTKTextureLoader(device: device)
       
        let ciContext = CIContext(mtlDevice: device)
        
        // TODO: Instead of creating this kernelFunction every time a new inputImage is passed
        // We can create this just once
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "colorMatchingKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            return nil
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: Int(inputImage.extent.width), height: Int(inputImage.extent.height), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        guard let cgImage = ciContext.createCGImage(inputImage, from: inputImage.extent) else {
            print("Error: inputImage does not have a valid CGImage")
            return nil
        }
        
        guard let inputTexture = try? textureLoader.newTexture(cgImage: cgImage, options: options) else {
            return nil
        }

        // commandEncoder is used for compute pipeline instead of the traditional render pipeline
        guard let outputTexture = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }

        let grayscaleBuffer = device.makeBuffer(bytes: grayscaleValues, length: grayscaleValues.count * MemoryLayout<Float>.size, options: [])
        let colorBuffer = device.makeBuffer(bytes: colorValues.map { SIMD3<Float>(Float($0.red), Float($0.green), Float($0.blue)) }, length: colorValues.count * MemoryLayout<SIMD3<Float>>.size, options: [])
        
        commandEncoder.setComputePipelineState(pipeline)
        commandEncoder.setTexture(inputTexture, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.setBuffer(grayscaleBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(colorBuffer, offset: 0, index: 1)
        commandEncoder.setBytes([UInt32(grayscaleValues.count)], length: MemoryLayout<UInt32>.size, index: 2)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
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
