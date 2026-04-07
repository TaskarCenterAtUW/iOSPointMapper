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
 A grid of world points structured for efficient spatial queries based on their projected pixel coordinates.
 */
struct WorldPointsGrid {
    let width: Int
    let height: Int
    var data: [WorldPointGridCell]
    
    subscript(x: Int, y: Int) -> WorldPointGridCell {
        get { return data[y * width + x] }
        set { data[y * width + x] = newValue }
    }
}

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
    ) throws -> WorldPointsGrid {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw WorldPointsProcessorError.metalPipelineCreationError
        }
        let pointCount = worldPoints.count
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)
        if pointCount == 0 {
            throw WorldPointsProcessorError.noWorldPointsToProcess
        }
        let gridCapacity = width * height
        
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
        let gridBufferLength = MemoryLayout<WorldPointGridCell>.stride * gridCapacity
        let gridBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: gridBufferLength,
            options: .storageModeShared
        )
        
        /**
         Initialize output buffer
         */
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw WorldPointsProcessorError.metalPipelineBlitEncoderError
        }
        blit.fill(buffer: gridBuffer, range: 0..<gridBufferLength, value: 0)
        blit.endEncoding()
        
        let threadGroupSizeWidth = min(self.gridPipeline.maxTotalThreadsPerThreadgroup, 256)
        
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
        var gridData = Array(
            repeating: WorldPointGridCell(worldPoint: WorldPoint(p: simd_float3(0, 0, 0)), isValid: UInt32(0)),
            count: gridCapacity
        )
        let gridBufferPtr = gridBuffer.contents().bindMemory(to: WorldPointGridCell.self, capacity: gridCapacity)
        for i in 0..<gridCapacity {
            let worldPointGridCell = gridBufferPtr[i]
            guard worldPointGridCell.isValid != 0 else { continue }
            gridData[i] = worldPointGridCell
        }
        return WorldPointsGrid(width: width, height: height, data: gridData)
    }
    
    /**
        Restructure world points into a 2D grid based on their projected pixel coordinates, for more efficient spatial queries.
     */
    func getWorldPointsGridCPU(
        worldPoints: [WorldPoint],
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> WorldPointsGrid {
        let width = Int(imageSize.width)
        let height = Int(imageSize.height)
        let gridData = Array(
            repeating: WorldPointGridCell(worldPoint: WorldPoint(p: simd_float3(0, 0, 0)), isValid: UInt32(0)),
            count: width * height
        )
        var worldPointGrid: WorldPointsGrid = WorldPointsGrid(width: width, height: height, data: gridData)
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
            worldPointGrid[x, y] = WorldPointGridCell(worldPoint: worldPoint, isValid: UInt32(1))
        }
        return worldPointGrid
    }
}
