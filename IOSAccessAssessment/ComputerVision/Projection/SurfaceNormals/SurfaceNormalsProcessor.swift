//
//  SurfaceNormalsProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/6/26.
//

import ARKit
import RealityKit
import MetalKit
import simd

struct SurfaceNormalsForPointsGrid: Sendable {
    let width: Int
    let height: Int
    var data: [SurfaceNormalsForPointsGridCell]
    
    /// TODO: Handle out-of-bounds access more robustly, possibly with a custom error or by returning an optional.
    subscript(x: Int, y: Int) -> SurfaceNormalsForPointsGridCell {
        get { return data[y * width + x] }
        set { data[y * width + x] = newValue }
    }
}

enum SurfaceNormalsProcessorError: Error, LocalizedError {
    case metalInitializationFailed
    case metalPipelineCreationError
    case metalPipelineBlitEncoderError
    case invalidProjectedPlaneVectors
    case unableToProcessBufferData
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationFailed:
            return "Failed to initialize Metal resources."
        case .metalPipelineCreationError:
            return "Failed to create Metal compute pipeline."
        case .metalPipelineBlitEncoderError:
            return "Failed to create Blit Command Encoder for the Surface Normals Processor."
        case .invalidProjectedPlaneVectors:
            return "Invalid projected plane vectors."
        case .unableToProcessBufferData:
            return "Unable to process buffer data for surface normals grid."
        }
    }
}

struct SurfaceNormalsProcessor {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let computePipeline: MTLComputePipelineState
    let boundsPipeline: MTLComputePipelineState
    let textureLoader: MTKTextureLoader
    
    let ciContext: CIContext
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw SurfaceNormalsProcessorError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let computeKernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "computeSurfaceNormals"),
              let computePipeline = try? device.makeComputePipelineState(function: computeKernelFunction) else {
            throw SurfaceNormalsProcessorError.metalInitializationFailed
        }
        guard let boundsKernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "getSurfaceNormalsWithinBounds"),
              let boundsPipeline = try? device.makeComputePipelineState(function: boundsKernelFunction) else {
            throw SurfaceNormalsProcessorError.metalInitializationFailed
        }
        self.computePipeline = computePipeline
        self.boundsPipeline = boundsPipeline
    }
    
    /**
     Computes surface normals from world points.
     These world points are arranged in a 2D grid based on their projected pixel coordinates, which allows for efficient spatial queries.
     The surface normals are computed by analyzing the local neighborhood of points in the grid, using the projected plane as a reference for determining the orientation of the surface. For each world point, we get two vectors: one along the longitudinal direction and one along lateral direction.
     Each vector is computed using neighbours equidistant and opposite to the point in the grid, within a specified maximum radius.
     The cross product of these two vectors gives the surface normal for that point.
     The surface normals are computed using the GPU for parallel processing, which can significantly speed up the operation for large point clouds.
     
     - Parameters:
        - worldPointsGrid: A grid of world points structured for efficient spatial queries based on their projected pixel coordinates.
        - projectedPlane: The projected plane used as a reference for determining the orientation of the surface.
        - minSteps: The minimum number of steps to take in each direction (longitudinal and lateral). In unnormalized coordinates.
        - maxSteps: The maximum number of steps to take in each direction (longitudinal and lateral). In unnormalized coordinates.
        - eps: A small epsilon value to reject degenerate vectors when computing the cross product.
     
     - Note:
     The sampling is done in DDA-style (Digital Differential Analyzer) to ensure that the neighbors are equidistant and opposite to the point in the grid.
     */
    func getSurfaceNormalsFromWorldPoints(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        projectedPlane: ProjectedPlane,
        minStep: Int = 4,
        maxStep: Int = 10,
        eps: Float = 1e-5
    ) throws -> SurfaceNormalsForPointsGrid {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw SurfaceNormalsProcessorError.metalPipelineCreationError
        }
        
        let width = worldPointsGrid.width
        let height = worldPointsGrid.height
        /// Sanity check with projected plane
        let dirL = normalize2D(projectedPlane.firstVector.1 - projectedPlane.firstVector.0)
        let dirT = normalize2D(projectedPlane.secondVector.1 - projectedPlane.secondVector.0)
        let stepL = makeStep(dirL)
        let stepT = makeStep(dirT)
        if simd_length(stepL) == 0 || simd_length(stepT) == 0 {
            throw SurfaceNormalsProcessorError.invalidProjectedPlaneVectors
        }
        
        let gridCapacity = width * height
        /// Set up the world points buffer
        /// TODO: Need to check if the worldPointsGrid.data is correctly laid out in memory for a contiguous copy.
        let worldPointsGridBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<WorldPointsGridCell>.stride * gridCapacity,
            options: .storageModeShared
        )
        let worldPointsGridBufferPtr = worldPointsGridBuffer.contents()
        try worldPointsGrid.data.withUnsafeBytes { srcPtr in
            guard let baseAddress = srcPtr.baseAddress else {
                throw WorldPointsProcessorError.unableToProcessBufferData
            }
            worldPointsGridBufferPtr.copyMemory(
                from: baseAddress, byteCount: MemoryLayout<WorldPointsGridCell>.stride * gridCapacity
            )
        }
        var widthLocal = UInt32(width)
        var heightLocal: UInt32 = UInt32(height)
        var params = SurfaceNormalsForPointsGridParams(
            minStep: UInt32(minStep), maxStep: UInt32(maxStep), eps: eps,
            longitudinalVector: plane.firstVector, lateralVector: plane.secondVector,
            normalVector: plane.normalVector, origin: plane.origin,
            projectedLongitudinalVector: simd_float2(projectedPlane.firstVector.1 - projectedPlane.firstVector.0),
            projectedLateralVector: simd_float2(projectedPlane.secondVector.1 - projectedPlane.secondVector.0),
            projectedNormalVector: simd_float2(projectedPlane.normalVector.1 - projectedPlane.normalVector.0),
            projectedOrigin: simd_float2(projectedPlane.origin),
            stepL: stepL, stepT: stepT
        )
        /// Setup the output buffer
        let gridBufferLength = MemoryLayout<SurfaceNormalsForPointsGridCell>.stride * gridCapacity
        let gridBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: gridBufferLength,
            options: .storageModeShared
        )
        
        /**
         Initialize output buffer
         */
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw SurfaceNormalsProcessorError.metalPipelineBlitEncoderError
        }
        blit.fill(buffer: gridBuffer, range: 0..<gridBufferLength, value: 0)
        blit.endEncoding()
        
        let threadGroupSizeWidth = min(self.computePipeline.maxTotalThreadsPerThreadgroup, 256)
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SurfaceNormalsProcessorError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.computePipeline)
        commandEncoder.setBuffer(worldPointsGridBuffer, offset: 0, index: 0)
        commandEncoder.setBytes(&widthLocal, length: MemoryLayout<UInt32>.size, index: 1)
        commandEncoder.setBytes(&heightLocal, length: MemoryLayout<UInt32>.size, index: 2)
        commandEncoder.setBytes(&params, length: MemoryLayout<SurfaceNormalsForPointsGridParams>.stride, index: 3)
        commandEncoder.setBuffer(gridBuffer, offset: 0, index: 4)
        
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (gridCapacity + threadGroupSize.width - 1) / threadGroupSize.width,
                                   height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        /// Process the output grid buffer to create the 2D grid of surface normals for points
        /// TODO: Consider using a more efficient method to read the data back from the GPU, especially for large grids.
        var surfaceNormalGridData = Array(repeating: SurfaceNormalsForPointsGridCell(
            worldPoint: WorldPoint(p: simd_float3(0, 0, 0)), surfaceNormal: simd_float3(0, 0, 0), isValid: UInt32(0)
        ), count: gridCapacity)
        let surfaceNormalGridBufferPtr = gridBuffer.contents().bindMemory(to: SurfaceNormalsForPointsGridCell.self, capacity: gridCapacity)
        for i in 0..<gridCapacity {
            let surfaceNormalGridCell = surfaceNormalGridBufferPtr[i]
            guard surfaceNormalGridCell.isValid != 0 else { continue }
            surfaceNormalGridData[i] = surfaceNormalGridCell
        }
        let surfaceNormalsGrid = SurfaceNormalsForPointsGrid(width: width, height: height, data: surfaceNormalGridData)
        return surfaceNormalsGrid
    }
    
    func getSurfaceNormalsFromWorldPointsCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        projectedPlane: ProjectedPlane,
        minStep: Int = 4,
        maxStep: Int = 10,
        eps: Float = 1e-5
    ) throws -> SurfaceNormalsForPointsGrid {
        let width = worldPointsGrid.width
        let height = worldPointsGrid.height
        let referenceNormal = plane.normalVector
        
        var surfaceNormalsGrid = SurfaceNormalsForPointsGrid(
            width: width, height: height,
            data: Array(repeating: SurfaceNormalsForPointsGridCell(
                worldPoint: WorldPoint(p: simd_float3(0, 0, 0)), surfaceNormal: simd_float3(0, 0, 0), isValid: UInt32(0)
            ), count: width * height)
        )
        let dirL = normalize2D(projectedPlane.firstVector.1 - projectedPlane.firstVector.0)
        let dirT = normalize2D(projectedPlane.secondVector.1 - projectedPlane.secondVector.0)
        let stepL = makeStep(dirL)
        let stepT = makeStep(dirT)
        if simd_length(stepL) == 0 || simd_length(stepT) == 0 {
            throw SurfaceNormalsProcessorError.invalidProjectedPlaneVectors
        }
        
        /// Define helper functions for neighbor sampling
        func walkDirection(startX: Int, startY: Int, step: SIMD2<Float>, sign: Float) -> SIMD3<Float>? {
            var pos = SIMD2<Float>(Float(startX), Float(startY))
            var pointSum: SIMD3<Float> = simd_float3(0, 0, 0)
            var weightSum: Float = 0
            
            for stepIndex in minStep...maxStep {
                pos += step * sign
                
                let xi = Int(pos.x)
                let yi = Int(pos.y)
                
                // Bounds check
                if xi < 0 || xi >= width || yi < 0 || yi >= height {
                    break
                }
                
                let neighbor = worldPointsGrid[xi, yi]
                if neighbor.isValid != 0 {
                    let weight = 1.0 / Float(stepIndex)
                    pointSum += neighbor.worldPoint.p * weight
                    weightSum += weight
                }
            }
            
            return weightSum > 0 ? pointSum / weightSum : nil
        }
        func alignNormalWithReference(_ normal: SIMD3<Float>) -> SIMD3<Float> {
            return simd_dot(normal, referenceNormal) < 0 ? -normal : normal
        }
        
        for y in 0..<height {
            for x in 0..<width {
                let cell = worldPointsGrid[x, y]
                guard cell.isValid != 0 else { continue }
                
                guard let pLPlus  = walkDirection(startX: x, startY: y, step: stepL, sign: +1),
                      let pLMinus = walkDirection(startX: x, startY: y, step: stepL, sign: -1),
                      let pTPlus  = walkDirection(startX: x, startY: y, step: stepT, sign: +1),
                      let pTMinus = walkDirection(startX: x, startY: y, step: stepT, sign: -1)
                else {
                    continue
                }
                let vL = pLPlus - pLMinus
                let vT = pTPlus - pTMinus
                let lenL2 = simd_length_squared(vL)
                let lenT2 = simd_length_squared(vT)
                /// Reject degenerate vectors
                if lenL2 < eps || lenT2 < eps {
                    continue
                }
                let normal = simd_cross(vL, vT)
                let lenNormal2 = simd_length_squared(normal)
                let sinSquared = lenNormal2 / (lenL2 * lenT2)
                if sinSquared < eps {
                    continue
                }
                let normalizedNormal = simd_normalize(alignNormalWithReference(normal))
                surfaceNormalsGrid[x, y] = SurfaceNormalsForPointsGridCell(
                    worldPoint: cell.worldPoint,
                    surfaceNormal: normalizedNormal,
                    isValid: UInt32(1)
                )
            }
        }
        return surfaceNormalsGrid
    }
    
    private func normalize2D(_ v: SIMD2<Float>) -> SIMD2<Float> {
        let len = simd_length(v)
        return len > 0 ? v / len : SIMD2<Float>(0, 0)
    }
    
    private func makeStep(_ dir: SIMD2<Float>) -> SIMD2<Float> {
        let maxComp = max(abs(dir.x), abs(dir.y))
        if maxComp == 0 { return SIMD2<Float>(0, 0) }
        return dir / maxComp
    }
    
    func debugSurfaceNormalsFromWorldPoints(surfaceNormalsGrid: SurfaceNormalsForPointsGrid) {
        var validPointCount = 0
        var validSurfaceNormalCount = 0
        let upVector = simd_float3(0, 1, 0)
        var averageNormalYAngles: [Float] = []
        
        for y in 0..<surfaceNormalsGrid.height {
            for x in 0..<surfaceNormalsGrid.width {
                let cell = surfaceNormalsGrid[x, y]
                if cell.isValid != 0 {
                    validPointCount += 1
                    let normal = cell.surfaceNormal
                    validSurfaceNormalCount += 1
                    averageNormalYAngles.append(acos(simd_dot(normal, upVector)))
                }
            }
        }
        let angleBuckets = stride(from: 0, to: 180, by: 10).map { bucketStart -> (range: String, count: Int) in
            let bucketEnd = bucketStart + 10
            let count = averageNormalYAngles.filter { angle in
                let angleDegrees = angle * 180 / .pi
                return angleDegrees >= Float(bucketStart) && angleDegrees < Float(bucketEnd)
            }.count
            return ("\(bucketStart)-\(bucketEnd)", count)
        }
        print("Valid Points: \(validPointCount), Valid Surface Normals: \(validSurfaceNormalCount)")
        print(angleBuckets.map { "\($0.range): \($0.count)" }.joined(separator: ", "))
    }
}
