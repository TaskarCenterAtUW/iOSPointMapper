//
//  ProjectedWorldPointsExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/5/26.
//

import ARKit
import RealityKit
import MetalKit
import simd
import PointNMapShaderTypes

/**
 Extension for projecting world points to plane and unprojecting them back to world coordinates.
 */
public extension WorldPointsProcessor {
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
        var params = ProjectedPointsParams(
            imageSize: simd_uint2(UInt32(imageSize.width), UInt32(imageSize.height)),
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics,
            longitudinalVector: simd_float3(plane.firstVector),
            lateralVector: simd_float3(plane.secondVector),
            normalVector: simd_float3(plane.normalVector),
            origin: simd_float3(plane.origin)
        )
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
        
        /// TODO: Consider using a more efficient way to read back the projected points, especially for large point counts. This current approach may not scale well.
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
    
    func unprojectPointsFromPlaneCPU(
        projectedPoints: [ProjectedPoint],
        plane: Plane
    ) throws -> [WorldPoint] {
        let pointCount = projectedPoints.count
        if pointCount == 0 {
            return []
        }
        let longitudinalVector = simd_float3(plane.firstVector)
        let lateralVector = simd_float3(plane.secondVector)
//        let normalVector = simd_float3(plane.normalVector)
        let origin = simd_float3(plane.origin)
        var worldPoints: [WorldPoint] = []
        for i in 0..<pointCount {
            let projectedPoint = projectedPoints[i]
            let worldPointPosition = origin + projectedPoint.s * longitudinalVector + projectedPoint.t * lateralVector
            worldPoints.append(WorldPoint(p: worldPointPosition))
        }
        return worldPoints
    }
}
