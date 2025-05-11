//
//  UnionOfMasksFilter.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/10/25.
//
import UIKit
import Metal
import CoreImage
import MetalKit

struct UnionOfMasksProcessor {
    // Metal-related properties
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext
    
    var arrayTexture: MTLTexture?
    var imageCount: Int = 0
    var format: MTLPixelFormat = .rgba8Unorm
    var width: Int = 0
    var height: Int = 0
    
    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            fatalError("Error: Failed to initialize Metal resources")
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device)
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "unionOfMasksKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            fatalError("Error: Failed to initialize Metal pipeline")
        }
        self.pipeline = pipeline
    }
    
    mutating func setArrayTexture(images: [CIImage]) {
        let imageCount = images.count
        guard imageCount > 0 else {
            print("Error: No images provided")
            return
        }
        let inputImage = images[0]
        
        let format: MTLPixelFormat = .rgba8Unorm
        let width = Int(inputImage.extent.width)
        let height = Int(inputImage.extent.height)
        
        // Assuming every image has the same size
        let individualDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format, width: width, height: height, mipmapped: false)
        individualDescriptor.usage = [.shaderRead, .shaderWrite]
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.textureType = .type2DArray
        descriptor.usage = [.shaderRead]
        descriptor.arrayLength = imageCount
        
        guard let arrayTexture = device.makeTexture(descriptor: descriptor) else {
            print("Error: Failed to create texture array")
            return
        }
        
        let bpp = self.bytesPerPixel(for: format)
        let bytesPerRow = width * bpp
        let bytesPerImage = bytesPerRow * height
        
        for (i, image) in images.enumerated() {
            guard let inputTexture = self.ciImageToTexture(image: image, descriptor: individualDescriptor, options: options) else {
                print("Error: Failed to create texture from CIImage")
                return
            }
            let region = MTLRegionMake2D(0, 0, width, height)
            
            var data = [UInt8](repeating: 0, count: bytesPerImage)
            inputTexture.getBytes(
                &data,
                bytesPerRow: bytesPerRow,
                from: region,
                mipmapLevel: 0)
            arrayTexture.replace(
                region: region,
                mipmapLevel: 0,
                slice: i,
                withBytes: data,
                bytesPerRow: bytesPerRow,
                bytesPerImage: bytesPerImage)
        }
        
        self.arrayTexture = arrayTexture
        self.imageCount = imageCount
        self.width = width
        self.height = height
        self.format = format
    }
    
    func apply(targetValue: UInt8) -> CIImage? {
        guard let inputImages = self.arrayTexture else {
            return nil
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: self.format, width: self.width, height: self.height,
                                                                  mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        // commandEncoder is used for compute pipeline instead of the traditional render pipeline
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor),
              let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        var imageCountLocal = self.imageCount
        var targetValueLocal = targetValue
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setTexture(inputImages, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.setBytes(&imageCountLocal, length: MemoryLayout<Int>.size, index: 0)
        commandEncoder.setBytes(&targetValueLocal, length: MemoryLayout<UInt8>.size, index: 1)
        
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (self.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (self.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return CIImage(mtlTexture: outputTexture, options: [.colorSpace: CGColorSpaceCreateDeviceGray()])
    }
    
    private func ciImageToTexture(image: CIImage, descriptor: MTLTextureDescriptor, options: [MTKTextureLoader.Option: Any]) -> MTLTexture? {
        guard let cgImage = self.ciContext.createCGImage(image, from: image.extent) else {
            print("Error: inputImage does not have a valid CGImage")
            return nil
        }
        guard let inputTexture = try? self.textureLoader.newTexture(cgImage: cgImage, options: options) else {
            return nil
        }
        return inputTexture
    }
    
    private func bytesPerPixel(for format: MTLPixelFormat) -> Int {
        switch format {
        case .r8Unorm: return 1
        case .r32Float: return 4
        case .rgba8Unorm: return 4
        case .bgra8Unorm: return 4
        default:
            fatalError("Unsupported pixel format: \(format.rawValue)")
        }
    }

}

extension UnionOfMasksProcessor {
//    func ciImagesToTexture2DArray(ciImages: [CIImage],
//                                   context: CIContext,
//                                   device: MTLDevice,
//                                   width: Int,
//                                   height: Int,
//                                   pixelFormat: MTLPixelFormat = .r8Unorm) -> MTLTexture? {
//        // 1. Create destination texture2D array
//        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
//                                                                  width: width,
//                                                                  height: height,
//                                                                  mipmapped: false)
//        descriptor.textureType = .type2DArray
//        descriptor.usage = [.shaderRead, .shaderWrite]
//        descriptor.arrayLength = ciImages.count
//
//        guard let textureArray = device.makeTexture(descriptor: descriptor) else {
//            return nil
//        }
//
//        // 2. Create temporary CVPixelBuffer (grayscale format for mask)
//        let attrs: [CFString: Any] = [
//            kCVPixelBufferCGImageCompatibilityKey: true,
//            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
//            kCVPixelBufferMetalCompatibilityKey: true
//        ]
//
//        let pixelBufferOptions = attrs as CFDictionary
//
//        for (i, image) in ciImages.enumerated() {
//            var pixelBuffer: CVPixelBuffer?
//            CVPixelBufferCreate(kCFAllocatorDefault, width, height,
//                                kCVPixelFormatType_OneComponent8,
//                                pixelBufferOptions,
//                                &pixelBuffer)
//
//            guard let buffer = pixelBuffer else { continue }
//
//            // 3. Render CIImage into pixel buffer
//            context.render(image, to: buffer)
//
//            // 4. Create a temporary MTLTexture from pixel buffer
//            var cvTextureOut: CVMetalTexture?
//            let textureCache: CVMetalTextureCache
//            var cache: CVMetalTextureCache?
//            CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
//            guard let texCache = cache else { return nil }
//            textureCache = texCache
//
//            CVMetalTextureCacheCreateTextureFromImage(nil, textureCache,
//                                                      buffer,
//                                                      nil,
//                                                      pixelFormat,
//                                                      width,
//                                                      height,
//                                                      0,
//                                                      &cvTextureOut)
//
//            guard let cvTex = cvTextureOut,
//                  let srcTexture = CVMetalTextureGetTexture(cvTex) else {
//                continue
//            }
//
//            // 5. Copy the rendered result into the correct slice
//            let region = MTLRegionMake2D(0, 0, width, height)
//            var data = [UInt8](repeating: 0, count: width * height)
//            srcTexture.getBytes(&data,
//                                bytesPerRow: width,
//                                from: region,
//                                mipmapLevel: 0)
//            textureArray.replace(region: region,
//                                 mipmapLevel: 0,
//                                 slice: i,
//                                 withBytes: data,
//                                 bytesPerRow: width)
//        }
//
//        return textureArray
//    }
}
