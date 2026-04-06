//
//  WorldPointsGridExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/5/26.
//

import ARKit
import RealityKit
import MetalKit
import simd

/**
 Extension for restructuring world points array into more efficient data structures for improved post-processing.
 */
extension WorldPointsProcessor {
    /**
        Restructure world points into a 2D grid based on their projected pixel coordinates, for more efficient spatial queries. This method uses the GPU for parallel processing of world points, which can significantly speed up the operation for large point clouds.
     */
    func getWorldPointsGrid(
        worldPoints: [WorldPoint],
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> [[WorldPoint?]] {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw WorldPointsProcessorError.metalPipelineCreationError
        }
        var pointCount = worldPoints.count
        if pointCount == 0 {
            return []
        }
        let gridCapacity = Int(imageSize.width) * Int(imageSize.height)
        
        /// Set up the world points buffer
        let worldPointsBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<WorldPoint>.stride * pointCount,
            options: .storageModeShared
        )
        let worldPointsBufferPtr = worldPointsBuffer.contents()
        try worldPoints.withUnsafeBytes { srcPtr in
            guard let baseAddress = srcPtr.baseAddress else {
                throw WorldPointsProcessorError.unableToProcessBufferData
            }
            worldPointsBufferPtr.copyMemory(from: baseAddress, byteCount: MemoryLayout<WorldPoint>.stride * pointCount)
        }
        let viewMatrix = cameraTransform.inverse
        var params = WorldPointGridParams(
            imageSize: simd_uint2(UInt32(imageSize.width), UInt32(imageSize.height)),
            viewMatrix: viewMatrix,
            cameraIntrinsics: cameraIntrinsics
        )
        /// Set up the output grid buffer
        let gridBufferLength = MemoryLayout<WorldPoint?>.stride * gridCapacity
        let gridBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: gridBufferLength,
            options: .storageModeShared
        )
        
        let threadGroupSizeWidth = min(self.projectionPipeline.maxTotalThreadsPerThreadgroup, 256)
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw WorldPointsProcessorError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.gridPipeline)
        commandEncoder.setBuffer(worldPointsBuffer, offset: 0, index: 0)
        commandEncoder.setBytes(&params, length: MemoryLayout<WorldPointGridParams>.stride, index: 1)
        commandEncoder.setBuffer(gridBuffer, offset: 0, index: 2)
        
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (pointCount + threadGroupSize.width - 1) / threadGroupSize.width,
                                   height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        /// Process the output grid buffer to create the 2D grid of world points
        /// TODO: Consider using a more efficient method to read back the grid data, especially for large images, as this could be a bottleneck. One option could be to read the buffer in chunks or use a more compact representation of the grid.
        var grid: [[WorldPoint?]] = Array(
            repeating: Array(repeating: Optional<WorldPoint>.none, count: Int(imageSize.width)),
            count: Int(imageSize.height)
        )
        let gridBufferPtr = gridBuffer.contents().bindMemory(to: Optional<WorldPoint>.self, capacity: gridCapacity)
        for i in 0..<gridCapacity {
            let worldPointOpt = gridBufferPtr[i]
            guard let worldPoint = worldPointOpt else {
                continue
            }
            let xIndex: Int = i % Int(imageSize.width)
            let yIndex: Int = i / Int(imageSize.width)
            guard xIndex >= 0, xIndex < Int(imageSize.width), yIndex >= 0, yIndex < Int(imageSize.height) else {
                continue
            }
            grid[yIndex][xIndex] = worldPoint
        }
        return grid
    }
    
    /**
        Restructure world points into a 2D grid based on their projected pixel coordinates, for more efficient spatial queries.
     */
    func getWorldPointsGridCPU(
        worldPoints: [WorldPoint],
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> [[WorldPoint?]] {
        var grid = Array(
            repeating: Array(repeating: Optional<WorldPoint>.none, count: Int(imageSize.width)),
            count: Int(imageSize.height)
        )
        let viewMatrix = simd_inverse(cameraTransform)
        worldPoints.forEach { worldPoint in
            let pixelPoint: CGPoint? = ProjectionUtils.unprojectWorldToPixel(
                worldPoint: worldPoint.p, viewMatrix: viewMatrix,
                cameraIntrinsics: cameraIntrinsics, imageSize: imageSize
            )
            guard let pixelPoint = pixelPoint else {
                return
            }
            let x = Int(pixelPoint.x)
            let y = Int(pixelPoint.y)
            guard x >= 0, x < Int(imageSize.width), y >= 0, y < Int(imageSize.height) else {
                return
            }
            /// Store the world point in the corresponding grid cell
            grid[y][x] = worldPoint
        }
        return grid
    }
}
