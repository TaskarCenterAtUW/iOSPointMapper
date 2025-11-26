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

enum UnionOfMasksProcessorError: Error, LocalizedError {
    case metalInitializationFailed
    case metalPipelineCreationError
    case invalidInputImage
    case textureCreationFailed
    case arrayTextureNotSet
    case outputImageCreationFailed
    case invalidPixelFormat
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationFailed:
            return "Failed to initialize Metal resources."
        case .metalPipelineCreationError:
            return "Failed to create Metal compute pipeline."
        case .invalidInputImage:
            return "The input image is invalid."
        case .textureCreationFailed:
            return "Failed to create Metal textures."
        case .arrayTextureNotSet:
            return "The array texture has not been set."
        case .outputImageCreationFailed:
            return "Failed to create output CIImage from Metal texture."
        case .invalidPixelFormat:
            return "The specified pixel format is invalid or unsupported."
        }
    }
}

/**
 UnionOfMasksProcessor is a class that processes an array of CIImages to compute the union of masks using Metal.
 It performs a simple weighted union operation on the input images, where each image is treated as a mask. Only the last frame can be weighted differently from the rest.
 */
class UnionOfMasksProcessor {
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
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw UnionOfMasksProcessorError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "unionOfMasksKernel"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw UnionOfMasksProcessorError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }
    
    /**
        Sets the array texture from an array of CIImages.
     
        - Parameters:
            - images: An array of CIImage objects to be combined into an array texture.
            - format: The pixel format for the texture. Default is .rgba8Unorm.
     */
    // FIXME: Sometimes, the array texture is not set correctly.
    // This could be due to the way the AnnotationView's initialization is set up.
    func setArrayTexture(images: [CIImage], format: MTLPixelFormat = .r8Unorm) throws {
        let imageCount = images.count
        guard imageCount > 0 else {
            throw UnionOfMasksProcessorError.invalidInputImage
        }
        let inputImage = images[0]
        
        let width = Int(inputImage.extent.width)
        let height = Int(inputImage.extent.height)
        
        // Assuming every image has the same size
        let individualDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format, width: width, height: height, mipmapped: false)
        individualDescriptor.usage = [.shaderRead, .shaderWrite]
        let options: [MTKTextureLoader.Option: Any] = [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.textureType = .type2DArray
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.arrayLength = imageCount
        
        let bpp = try self.bytesPerPixel(for: format)
        let bytesPerRow = width * bpp
        let bytesPerImage = bytesPerRow * height
        
        guard let arrayTexture = device.makeTexture(descriptor: descriptor) else {
            throw UnionOfMasksProcessorError.textureCreationFailed
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw UnionOfMasksProcessorError.metalPipelineCreationError
        }
        
        var inputTextures: [MTLTexture] = []
        for (i, image) in images.enumerated() {
            guard image.extent.width == CGFloat(width),
                  image.extent.height == CGFloat(height) else {
                throw UnionOfMasksProcessorError.invalidInputImage
            }
//            guard let sliceTexture = arrayTexture.makeTextureView(
//                pixelFormat: format,
//                textureType: .type2D,
//                levels: 0..<1,
//                slices: i..<(i+1)
//            ) else { continue }
//            ciContext.render(
//                image,
//                to: sliceTexture,
//                commandBuffer: commandBuffer,
//                bounds: image.extent,
//                colorSpace: CGColorSpaceCreateDeviceRGB()
//            )
//            let inputTexture = try self.ciImageToTexture(image: image, descriptor: individualDescriptor, options: options)
            let inputTexture = try image.toMTLTexture(
                device: device, commandBuffer: commandBuffer,
                pixelFormat: format, context: ciContext,
                colorSpace: CGColorSpaceCreateDeviceRGB(), /// Dummy color space
                cIImageToMTLTextureOrientation: .metalTopLeft
            )
            inputTextures.append(inputTexture)
            
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        for (i, inputTexture) in inputTextures.enumerated() {
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
    
    func apply(targetValue: UInt8, unionOfMasksPolicy: UnionOfMasksPolicy = UnionOfMasksPolicy.default) throws -> CIImage {
        guard let inputImages = self.arrayTexture else {
            throw UnionOfMasksProcessorError.arrayTextureNotSet
        }
        
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: self.format, width: self.width, height: self.height,
                                                                  mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        
        // commandEncoder is used for compute pipeline instead of the traditional render pipeline
        guard let outputTexture = self.device.makeTexture(descriptor: descriptor),
              let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw UnionOfMasksProcessorError.textureCreationFailed
        }
        
        var imageCountLocal = self.imageCount
        var targetValueLocal = targetValue
        var unionOfMasksThresholdLocal = unionOfMasksPolicy.threshold
        var defaultFrameWeightLocal = unionOfMasksPolicy.defaultFrameWeight
        var lastFrameWeightLocal = unionOfMasksPolicy.lastFrameWeight
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setTexture(inputImages, index: 0)
        commandEncoder.setTexture(outputTexture, index: 1)
        commandEncoder.setBytes(&imageCountLocal, length: MemoryLayout<Int>.size, index: 0)
        commandEncoder.setBytes(&targetValueLocal, length: MemoryLayout<UInt8>.size, index: 1)
        commandEncoder.setBytes(&unionOfMasksThresholdLocal, length: MemoryLayout<Float>.size, index: 2)
        commandEncoder.setBytes(&defaultFrameWeightLocal, length: MemoryLayout<Float>.size, index: 3)
        commandEncoder.setBytes(&lastFrameWeightLocal, length: MemoryLayout<Float>.size, index: 4)
        
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (self.width + threadgroupSize.width - 1) / threadgroupSize.width,
                                   height: (self.height + threadgroupSize.height - 1) / threadgroupSize.height,
                                   depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        guard let resultImage = CIImage(mtlTexture: outputTexture, options: [.colorSpace: NSNull()]) else {
            throw UnionOfMasksProcessorError.outputImageCreationFailed
        }
        let resultImageOriented = resultImage
            .transformed(by: CGAffineTransform(scaleX: 1, y: -1))
            .transformed(by: CGAffineTransform(translationX: 0, y: resultImage.extent.height))
        return resultImageOriented
    }
    
    private func ciImageToTexture(
        image: CIImage, descriptor: MTLTextureDescriptor, options: [MTKTextureLoader.Option: Any]
    ) throws -> MTLTexture {
        guard let cgImage = self.ciContext.createCGImage(image, from: image.extent) else {
            throw UnionOfMasksProcessorError.invalidInputImage
        }
        guard let inputTexture = try? self.textureLoader.newTexture(cgImage: cgImage, options: options) else {
            throw UnionOfMasksProcessorError.textureCreationFailed
        }
        return inputTexture
    }
    
    private func bytesPerPixel(for format: MTLPixelFormat) throws -> Int {
        switch format {
        case .r8Unorm: return 1
        case .r32Float: return 4
        case .rgba8Unorm: return 4
        case .bgra8Unorm: return 4
        default:
            throw UnionOfMasksProcessorError.invalidPixelFormat
        }
    }
}
