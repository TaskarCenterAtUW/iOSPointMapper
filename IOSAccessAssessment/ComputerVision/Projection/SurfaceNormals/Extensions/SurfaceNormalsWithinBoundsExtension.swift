//
//  SurfaceNormalsWithinBoundsExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/7/26.
//

import ARKit
import RealityKit
import MetalKit
import simd

extension SurfaceNormalsProcessor {
    /// TODO: Eventually, optimize the size of the bounding box surface normal grids to be the size of the bounding box itself.
    func getSurfaceNormalsFromWorldPointsWithinBounds(
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> [DamageDetectionResult: SurfaceNormalsForPointsGrid] {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw SurfaceNormalsProcessorError.metalPipelineCreationError
        }
        
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        let gridCapacity = width * height
        let viewMatrix = simd_inverse(cameraTransform)
        
        var details: [BoundsParams] = []
        for damageDetectionResult in damageDetectionResults {
            let pixelRect: CGRect = damageDetectionResult.getPixelCGRect(for: imageSize)
            
            let minX = max(Float(pixelRect.minX), 0)
            let maxX = min(Float(pixelRect.maxX), Float(width) - 1)
            let minY = max(Float(pixelRect.minY), 0)
            let maxY = min(Float(pixelRect.maxY), Float(height) - 1)
            
            details.append(BoundsParams(
                minX: minX, minY: minY, maxX: maxX, maxY: maxY
            ))
        }
        
        let boxCount = damageDetectionResults.count
        
        /// Set up the input buffers
        let surfaceNormalsGridBufferLength = MemoryLayout<SurfaceNormalForPointGridCell>.stride * width * height
        let surfaceNormalsGridBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: surfaceNormalsGridBufferLength,
            options: .storageModeShared,
        )
        let surfaceNormalGridBufferPtr = surfaceNormalsGridBuffer.contents()
        try surfaceNormalsForPointsGrid.data.withUnsafeBytes { rawBufferPtr in
            guard let baseAddress = rawBufferPtr.baseAddress else {
                throw SurfaceNormalsProcessorError.unableToProcessBufferData
            }
            surfaceNormalGridBufferPtr.copyMemory(from: baseAddress, byteCount: surfaceNormalsGridBufferLength)
        }
        let boxesBufferLength = MemoryLayout<BoundsParams>.stride * boxCount
        let boxesBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: boxesBufferLength,
            options: .storageModeShared
        )
        let boxesBufferPtr = boxesBuffer.contents()
        try details.withUnsafeBytes { rawBufferPtr in
            guard let baseAddress = rawBufferPtr.baseAddress else {
                throw SurfaceNormalsProcessorError.unableToProcessBufferData
            }
            boxesBufferPtr.copyMemory(from: baseAddress, byteCount: boxesBufferLength)
        }
        var params = SurfaceNormalsWithinBoundsParams(
            gridWidth: UInt32(width), gridHeight: UInt32(height), boxCount: UInt32(boxCount),
            viewMatrix: viewMatrix, cameraIntrinsics: cameraIntrinsics,
            imageSize: simd_uint2(UInt32(imageSize.width), UInt32(imageSize.height))
        )
        
        /// Set up the output grid buffer
        let outputSurfaceNormalsGridBufferLength = MemoryLayout<SurfaceNormalForPointGridCell>.stride * width * height * boxCount
        let outputSurfaceNormalsGridBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: outputSurfaceNormalsGridBufferLength,
            options: .storageModeShared
        )
        
        /**
         Initialize output buffer
         */
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw SurfaceNormalsProcessorError.metalPipelineBlitEncoderError
        }
        blit.fill(buffer: outputSurfaceNormalsGridBuffer, range: 0..<outputSurfaceNormalsGridBufferLength, value: 0)
        blit.endEncoding()
        
        let threadGroupSizeWidth = min(self.boundsPipeline.maxTotalThreadsPerThreadgroup, 256)
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SurfaceNormalsProcessorError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.boundsPipeline)
        commandEncoder.setBuffer(surfaceNormalsGridBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(boxesBuffer, offset: 0, index: 1)
        commandEncoder.setBytes(&params, length: MemoryLayout<SurfaceNormalsWithinBoundsParams>.stride, index: 2)
        commandEncoder.setBuffer(outputSurfaceNormalsGridBuffer, offset: 0, index: 3)
        
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (gridCapacity + threadGroupSize.width - 1) / threadGroupSize.width,
                                   height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        /// Process the output buffer to get the surface normals for each bounding box
        /// TODO: Consider using a more efficient method to read the output buffer.
        var finalResults: [DamageDetectionResult: SurfaceNormalsForPointsGrid] = [:]
        let outputSurfaceNormalsGridBufferPtr = outputSurfaceNormalsGridBuffer.contents().bindMemory(
            to: SurfaceNormalForPointGridCell.self, capacity: outputSurfaceNormalsGridBufferLength
        )
        for i in 0..<boxCount {
            let surfaceNormalsData: [SurfaceNormalForPointGridCell] = Array(
                repeating: SurfaceNormalForPointGridCell(
                    worldPoint: WorldPoint(p: simd_float3(0, 0, 0)), surfaceNormal: simd_float3(0, 0, 0), isValid: UInt32(0)
                ),
                count: width * height
            )
            var surfaceNormalsGrid = SurfaceNormalsForPointsGrid(
                width: width, height: height, data: surfaceNormalsData
            )
            let baseOffset = i * gridCapacity
            for y in 0..<height {
                for x in 0..<width {
                    let outputCell = outputSurfaceNormalsGridBufferPtr[baseOffset + y * width + x]
                    surfaceNormalsGrid[x, y] = outputCell
                }
            }
            finalResults[damageDetectionResults[i]] = surfaceNormalsGrid
        }
//        debugSurfaceNormalsFromWorldPointsWithinBounds(results: finalResults)
        return finalResults
    }
    
    /// TODO: Eventually, optimize the size of the bounding box surface normal grids to be the size of the bounding box itself.
    /// While it is easy to do so in the CPU, to maintain consistency with the GPU implementation, we can keep the surface normal grids the same size as the original surfaceNormalsForPointsGrid, but only populate the values within the bounding box, and set the rest to invalid.
    func getSurfaceNormalsFromWorldPointsWithinBoundsCPU(
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> [DamageDetectionResult: SurfaceNormalsForPointsGrid] {
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        let viewMatrix = simd_inverse(cameraTransform)
        
        var details: [BoundsParams] = []
        var results: [SurfaceNormalsForPointsGrid] = []
        for damageDetectionResult in damageDetectionResults {            
            let surfaceNormalsData: [SurfaceNormalForPointGridCell] = Array(
                repeating: SurfaceNormalForPointGridCell(
                    worldPoint: WorldPoint(p: simd_float3(0, 0, 0)), surfaceNormal: simd_float3(0, 0, 0), isValid: UInt32(0)
                ),
                count: width * height
            )
            details.append(damageDetectionResult.getBoundsParams(for: imageSize))
            results.append(SurfaceNormalsForPointsGrid(
                width: width, height: height, data: surfaceNormalsData
            ))
        }
        for y in 0..<height {
            for x in 0..<width {
                let surfaceNormalForPointGridCell = surfaceNormalsForPointsGrid[x, y]
                if surfaceNormalForPointGridCell.isValid == 0 { continue }
                let pixelPoint: CGPoint? = ProjectionUtils.unprojectWorldToPixel(
                    worldPoint: surfaceNormalForPointGridCell.worldPoint.p, viewMatrix: viewMatrix,
                    cameraIntrinsics: cameraIntrinsics, imageSize: imageSize
                )
                guard let pixelPoint = pixelPoint else {
                    continue
                }
                let pixelX = Int(pixelPoint.x)
                let pixelY = Int(pixelPoint.y)
                
                for i in 0..<damageDetectionResults.count {
                    /// Check if the pixel point is within the bounding box of the damage detection result
                    let detail = details[i]
                    guard pixelX >= Int(detail.minX) && pixelX <= Int(detail.maxX) &&
                        pixelY >= Int(detail.minY) && pixelY <= Int(detail.maxY) else {
                        continue
                    }
                    // If it is, add the surface normal for that point to the surfaceNormalsData array
                    results[i][pixelX, pixelY] = surfaceNormalForPointGridCell
                }
            }
        }
        var finalResults: [DamageDetectionResult: SurfaceNormalsForPointsGrid] = [:]
        for i in 0..<damageDetectionResults.count {
            finalResults[damageDetectionResults[i]] = results[i]
        }
//        debugSurfaceNormalsFromWorldPointsWithinBounds(results: finalResults)
        return finalResults
    }
    
    private func debugSurfaceNormalsFromWorldPointsWithinBounds(
        results: [DamageDetectionResult: SurfaceNormalsForPointsGrid]
    ) {
        print("Surface Normals for Damage Detection Results:")
        for (result, grid) in results {
            print("\nDamage Detection Result: \(result)")
            debugSurfaceNormalsFromWorldPoints(surfaceNormalsGrid: grid)
        }
    }
}
