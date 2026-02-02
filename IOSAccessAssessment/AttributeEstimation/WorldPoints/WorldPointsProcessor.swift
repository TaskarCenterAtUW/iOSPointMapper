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
    case unableToProcessBufferData
    
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
        case .unableToProcessBufferData:
            return "Unable to process data from CVPixelBuffer."
        }
    }
}

/**
 Extacting 3D world points.
 */
struct WorldPointsProcessor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private let worldPointsPipeline: MTLComputePipelineState
    private let projectionPipeline: MTLComputePipelineState
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
        
        guard let worldPointskernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "computeWorldPoints"),
              let worldPointsPipeline = try? device.makeComputePipelineState(function: worldPointskernelFunction) else {
            throw WorldPointsProcessorError.metalInitializationFailed
        }
        self.worldPointsPipeline = worldPointsPipeline
        guard let projectionKernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "projectPointsToPlane"),
              let projectionPipeline = try? device.makeComputePipelineState(function: projectionKernelFunction) else {
            throw WorldPointsProcessorError.metalInitializationFailed
        }
        self.projectionPipeline = projectionPipeline
    }
    
    /**
        Extract world points from segmentation and depth images (GPU version).
     */
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
        let resizedDepthImage = depthImage.resized(to: segmentationLabelImage.extent.size)
        let depthTexture = try resizedDepthImage.toMTLTexture(
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
        
        commandEncoder.setComputePipelineState(self.worldPointsPipeline)
        commandEncoder.setTexture(segmentationLabelTexture, index: 0)
        commandEncoder.setTexture(depthTexture, index: 1)
        commandEncoder.setBytes(&targetValueVar, length: MemoryLayout<UInt8>.size, index: 0)
        commandEncoder.setBytes(&params, length: MemoryLayout<WorldPointsParams>.stride, index: 1)
        commandEncoder.setBuffer(pointsBuffer, offset: 0, index: 2)
        commandEncoder.setBuffer(pointCount, offset: 0, index: 3)
        commandEncoder.setBuffer(debugBuffer, offset: 0, index: 4)
        
        let threadgroupSize = MTLSize(width: worldPointsPipeline.threadExecutionWidth, height: worldPointsPipeline.maxTotalThreadsPerThreadgroup / worldPointsPipeline.threadExecutionWidth, depth: 1)
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
//        let dbg = debugBuffer.contents().bindMemory(to: UInt32.self, capacity: debugCountSlots)
        
        return worldPoints
    }
    
    /**
        Compute world point from pixel coordinate and depth value (CPU version).
     
        Taking reference from `LocalizationProcessor`
     */
    private func computeWorldPointCPU(
        pixelCoord: SIMD2<Int>,
        depthValue: Float,
        cameraTransform: simd_float4x4,
        invIntrinsics: simd_float3x3
    ) -> WorldPoint {
        let imagePoint = simd_float3(Float(pixelCoord.x), Float(pixelCoord.y), 1.0)
        let ray = invIntrinsics * imagePoint
        let rayDirection = simd_normalize(ray)
        
        var cameraPoint = rayDirection * depthValue
        cameraPoint.y = -cameraPoint.y
        cameraPoint.z = -cameraPoint.z
        let cameraPoint4 = simd_float4(cameraPoint, 1.0)
        
        let worldPoint4 = cameraTransform * cameraPoint4
        let worldPoint = SIMD3<Float>(worldPoint4.x, worldPoint4.y, worldPoint4.z) / worldPoint4.w
        
        return WorldPoint(p: worldPoint)
    }
    
    /**
        Extract world points from segmentation and depth images (CPU version).
     */
    func getWorldPointsCPU(
        segmentationLabelImage: CIImage,
        depthImage: CIImage,
        targetValue: UInt8,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) throws -> [WorldPoint] {
        let minDepthThreshold = Constants.DepthConstants.depthMinThreshold
        let maxDepthThreshold = Constants.DepthConstants.depthMaxThreshold
        let invIntrinsics = simd_inverse(cameraIntrinsics)
        
        /// Get CVPixelBuffer from segmentation image
        let segmentationLabelPixelBuffer = try segmentationLabelImage.toPixelBuffer(
            context: self.ciContext,
            pixelFormatType: kCVPixelFormatType_OneComponent8,
            colorSpace: nil
        )
        let segmentationWidth = CVPixelBufferGetWidth(segmentationLabelPixelBuffer)
        let segmentationHeight = CVPixelBufferGetHeight(segmentationLabelPixelBuffer)
        let resizedDepthImage = depthImage.resized(to: segmentationLabelImage.extent.size)
        let depthBuffer = try resizedDepthImage.toPixelBuffer(
            context: self.ciContext,
            pixelFormatType: kCVPixelFormatType_DepthFloat32,
            colorSpace: nil
        )
        
        CVPixelBufferLockBaseAddress(segmentationLabelPixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(segmentationLabelPixelBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly)
        }
        
        guard let segmentationBaseAddress = CVPixelBufferGetBaseAddress(segmentationLabelPixelBuffer),
              let depthBaseAddress = CVPixelBufferGetBaseAddress(depthBuffer) else {
            throw WorldPointsProcessorError.unableToProcessBufferData
        }
        let segmentationBytesPerRow = CVPixelBufferGetBytesPerRow(segmentationLabelPixelBuffer)
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
        let segmentationPtr = segmentationBaseAddress.assumingMemoryBound(to: UInt8.self)
        let depthPtr = depthBaseAddress.assumingMemoryBound(to: Float.self)
        
        var worldPoints: [WorldPoint] = []
        for y in 0..<segmentationHeight {
            for x in 0..<segmentationWidth {
                let segmentationIndex = y * segmentationBytesPerRow / MemoryLayout<UInt8>.stride + x
                if segmentationPtr[segmentationIndex] != targetValue {
                    continue
                }
                let depthIndex = y * depthBytesPerRow / MemoryLayout<Float>.stride + x
                let depthValue = depthPtr[depthIndex]
                if depthValue < minDepthThreshold || depthValue > maxDepthThreshold {
                    continue
                }
                let worldPoint = self.computeWorldPointCPU(
                    pixelCoord: SIMD2<Int>(x, y),
                    depthValue: depthValue,
                    cameraTransform: cameraTransform,
                    invIntrinsics: invIntrinsics
                )
                worldPoints.append(worldPoint)
            }
        }
        
        return worldPoints
    }
    
    func projectPointsToPlane(
        worldPoints: [WorldPoint],
        plane: Plane,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> [ProjectedPoint] {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw WorldPointsProcessorError.metalPipelineCreationError
        }
        var pointCount = worldPoints.count
        if pointCount == 0 {
            return []
        }
        var params = ProjectedPointsParams(
            imageSize: simd_uint2(UInt32(imageSize.width), UInt32(imageSize.height)),
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics,
            longitudinalVector: simd_float3(plane.firstVector),
            lateralVector: simd_float3(plane.secondVector),
            normalVector: simd_float3(plane.normalVector),
            origin: simd_float3(plane.origin)
        )
        let worldPointsBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<WorldPoint>.stride * pointCount,
            options: .storageModeShared
        )
        /// Copy the world points data to the buffer
        let worldPointsBufferPtr = worldPointsBuffer.contents()
        worldPoints.withUnsafeBytes { srcPtr in
            guard let baseAddress = srcPtr.baseAddress else { return }
            worldPointsBufferPtr.copyMemory(from: baseAddress, byteCount: MemoryLayout<WorldPoint>.stride * pointCount)
        }
        
        let projectedPointsBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<ProjectedPoint>.stride * pointCount,
            options: .storageModeShared
        )
        
        let threadGroupSizeWidth = min(self.projectionPipeline.maxTotalThreadsPerThreadgroup, 256)
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw WorldPointsProcessorError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.projectionPipeline)
        commandEncoder.setBuffer(worldPointsBuffer, offset: 0, index: 0)
        commandEncoder.setBytes(&pointCount, length: MemoryLayout<UInt32>.stride, index: 1)
        commandEncoder.setBytes(&params, length: MemoryLayout<ProjectedPointsParams>.stride, index: 2)
        commandEncoder.setBuffer(projectedPointsBuffer, offset: 0, index: 3)
        
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (pointCount + threadGroupSize.width - 1) / threadGroupSize.width,
                                    height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        var projectedPoints: [ProjectedPoint] = []
        let projectedPointsPointer = projectedPointsBuffer.contents().bindMemory(to: ProjectedPoint.self, capacity: pointCount)
        for i in 0..<pointCount {
            let projectedPoint = projectedPointsPointer.advanced(by: i).pointee
            projectedPoints.append(projectedPoint)
        }
        return projectedPoints
    }
    
    func projectPointsToPlaneCPU(
        worldPoints: [WorldPoint],
        plane: Plane,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> [ProjectedPoint] {
        let pointCount = worldPoints.count
        if pointCount == 0 {
            return []
        }
        let longitudinalVector = simd_float3(plane.firstVector)
        let lateralVector = simd_float3(plane.secondVector)
//        let normalVector = simd_float3(plane.normalVector)
        let origin = simd_float3(plane.origin)
        var projectedPoints: [ProjectedPoint] = []
        for i in 0..<pointCount {
            let worldPoint = worldPoints[i].p
            let s = simd_dot(worldPoint - origin, longitudinalVector)
            let t = simd_dot(worldPoint - origin, lateralVector)
            projectedPoints.append(
                ProjectedPoint(s: s, t: t)
            )
        }
        return projectedPoints
    }
}
