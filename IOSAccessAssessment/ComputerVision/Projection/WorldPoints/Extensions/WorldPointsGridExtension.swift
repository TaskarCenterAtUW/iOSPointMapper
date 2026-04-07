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
struct WorldPointsGrid: Sendable {
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
        var pointCountLocal = UInt32(pointCount)
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
        commandEncoder.setBytes(&pointCountLocal, length: MemoryLayout<UInt32>.size, index: 1)
        commandEncoder.setBytes(&params, length: MemoryLayout<WorldPointGridParams>.stride, index: 2)
        commandEncoder.setBuffer(gridBuffer, offset: 0, index: 3)
        
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
        let worldPointsGrid = WorldPointsGrid(width: width, height: height, data: gridData)
        return worldPointsGrid
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
        if worldPoints.isEmpty {
            throw WorldPointsProcessorError.noWorldPointsToProcess
        }
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
    
    private func debugWorldPointGrid(
        worldPointGrid: WorldPointsGrid
    ) {
        var worldPointData: [WorldPoint] = []
        var worldPointLengthData: [Float] = []
        var sumPoints: simd_float3 = simd_float3(0, 0, 0)
        for y in 0..<worldPointGrid.height {
            for x in 0..<worldPointGrid.width {
                let cell = worldPointGrid[x, y]
                if cell.isValid != 0 {
                    worldPointData.append(cell.worldPoint)
                    worldPointLengthData.append(simd_length(cell.worldPoint.p))
                    sumPoints += cell.worldPoint.p
                }
            }
        }
        print("Debug World Point Grid: Total Valid Points = \(worldPointData.count)")
        print("Middle Point: \(sumPoints / Float(worldPointData.count))")
        /// Analyze distribution of world point distances
        let meanDistance = worldPointLengthData.reduce(0, +) / Float(worldPointLengthData.count)
        let sortedDistances = worldPointLengthData.sorted()
        let medianDistance = sortedDistances[sortedDistances.count / 2]
        print("Mean Distance: \(meanDistance), Median Distance: \(medianDistance)")
    }
}
