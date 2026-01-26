//
//  WorldPointsProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/25/26.
//

import ARKit
import RealityKit
import MetalKit
import simd

enum WorldPointsProcessorError: Error, LocalizedError {
    case metalInitializationFailed
    case invalidInputImage
    case textureCreationFailed
    case metalPipelineCreationError
    case meshPipelineBlitEncoderError
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
        case .meshPipelineBlitEncoderError:
            return "Failed to create Blit Command Encoder for the Segmentation Mesh Creation."
        case .outputImageCreationFailed:
            return "Failed to create output CIImage from Metal texture."
        }
    }
}

/**
 Extacting 3D world points.
 */
struct WorldPointsProcessor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw WorldPointsProcessorError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "computeWorldPoints"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw WorldPointsProcessorError.metalInitializationFailed
        }
        self.pipeline = pipeline
    }
    
    func getWorldPoints(
        segmentationLabelImage: CIImage,
        depthImage: CIImage,
        targetValue: UInt8,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) throws -> [WorldPoint] {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw WorldPointsProcessorError.metalPipelineCreationError
        }
        
        let imageSize = simd_uint2(UInt32(segmentationLabelImage.extent.width), UInt32(segmentationLabelImage.extent.height))
        let invIntrinsics = simd_inverse(cameraIntrinsics)
        
        let segmentationLabelTexture = try segmentationLabelImage.toMTLTexture(
            device: self.device, commandBuffer: commandBuffer, pixelFormat: .r8Unorm,
            context: self.ciContext,
            colorSpace: CGColorSpaceCreateDeviceRGB() /// Dummy color space
        )
        let depthTexture = try depthImage.toMTLTexture(
            device: self.device, commandBuffer: commandBuffer, pixelFormat: .r32Float,
            context: self.ciContext,
            colorSpace: CGColorSpaceCreateDeviceRGB() /// Dummy color space
        )
        var targetValueVar = targetValue
        var params = WorldPointsParams(
            imageSize: imageSize,
            minDepthThreshold: Constants.DepthConstants.depthMinThreshold,
            maxDepthThreshold: Constants.DepthConstants.depthMaxThreshold,
            cameraTransform: cameraTransform,
            invIntrinsics: invIntrinsics
        )
        let pointCount: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device, length: MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        let maxPoints = imageSize.x * imageSize.y
        let pointsBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device, length: MemoryLayout<WorldPoint>.stride * Int(maxPoints), options: .storageModeShared
        )
        let debugCountSlots = 6
        let debugBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<UInt32>.stride * debugCountSlots,
            options: .storageModeShared
        )
        
        /**
         Initialize point count to zero.
         */
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw WorldPointsProcessorError.meshPipelineBlitEncoderError
        }
        blit.fill(buffer: pointCount, range: 0..<MemoryLayout<UInt32>.stride, value: 0)
        blit.fill(buffer: debugBuffer, range: 0..<(MemoryLayout<UInt32>.stride * debugCountSlots), value: 0)
        blit.endEncoding()
        
        /**
            Encode compute command.
         */
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw WorldPointsProcessorError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.pipeline)
        commandEncoder.setTexture(segmentationLabelTexture, index: 0)
        commandEncoder.setTexture(depthTexture, index: 1)
        commandEncoder.setBytes(&targetValueVar, length: MemoryLayout<UInt8>.size, index: 0)
        commandEncoder.setBytes(&params, length: MemoryLayout<WorldPointsParams>.stride, index: 1)
        commandEncoder.setBuffer(pointsBuffer, offset: 0, index: 2)
        commandEncoder.setBuffer(pointCount, offset: 0, index: 3)
        commandEncoder.setBuffer(debugBuffer, offset: 0, index: 4)
        
        let threadgroupSize = MTLSize(width: pipeline.threadExecutionWidth, height: pipeline.maxTotalThreadsPerThreadgroup / pipeline.threadExecutionWidth, depth: 1)
        let threadgroups = MTLSize(width: (Int(imageSize.x) + threadgroupSize.width - 1) / threadgroupSize.width,
                                      height: (Int(imageSize.y) + threadgroupSize.height - 1) / threadgroupSize.height,
                                        depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let pointsCountPointer = pointCount.contents().bindMemory(to: UInt32.self, capacity: 1).pointee
        let actualPointCount = Int(pointsCountPointer)
        var worldPoints: [WorldPoint] = []
        if actualPointCount > 0 {
            let pointsPointer = pointsBuffer.contents().bindMemory(to: WorldPoint.self, capacity: actualPointCount)
            for i in 0..<actualPointCount {
                let point = pointsPointer.advanced(by: i).pointee
                worldPoints.append(point)
            }
        }
        
        let dbg = debugBuffer.contents().bindMemory(to: UInt32.self, capacity: debugCountSlots)
        print("outsideImage:", dbg[0])
        print("unmatchedSegmentation:", dbg[1])
        print("belowDepthRange:", dbg[2])
        print("aboveDepthRange:", dbg[3])
        print("wrotePoint:", dbg[4])
        print("depthIsZero:", dbg[5])
        print("pointCount:", pointsCountPointer)
        
        return worldPoints
    }
}
