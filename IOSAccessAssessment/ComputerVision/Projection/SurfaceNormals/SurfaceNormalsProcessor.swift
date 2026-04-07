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
    var data: [SurfaceNormalForPointGridCell]
    
    subscript(x: Int, y: Int) -> SurfaceNormalForPointGridCell {
        get { return data[y * width + x] }
        set { data[y * width + x] = newValue }
    }
}

enum SurfaceNormalsProcessorError: Error, LocalizedError {
    case metalInitializationFailed
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationFailed:
            return "Failed to initialize Metal resources."
        }
    }
}

struct SurfaceNormalsProcessor {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    
    private let pipeline: MTLComputePipelineState
    private let textureLoader: MTKTextureLoader
    
    private let ciContext: CIContext
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw SurfaceNormalsProcessorError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "computeSurfaceNormals"),
              let pipeline = try? device.makeComputePipelineState(function: kernelFunction) else {
            throw SurfaceNormalsProcessorError.metalInitializationFailed
        }
        self.pipeline = pipeline
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
//    func getSurfaceNormalsFromWorldPoints(
//        worldPointsGrid: WorldPointsGrid,
//        projectedPlane: ProjectedPlane,
//        minStep: Int = 4,
//        maxStep: Int = 10,
//        eps: Float = 1e-5
//    ) throws -> SurfaceNormalsForPointsGrid {
//        let width = worldPointsGrid.width
//        let height = worldPointsGrid.height
//        
//        let gridCapacity = width * height
//        /// Set up the world points buffer
//        let worldPointsBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
//            device: self.device,
//            length: MemoryLayout<WorldPointGridCell>.stride * gridCapacity,
//            options: .storageModeShared
//        )
//        let worldPointsBufferPtr = worldPointsBuffer.contents()
//        try worldPointsGrid.data.withUnsafeBytes { srcPtr in
//            guard let baseAddress = srcPtr.baseAddress else {
//                throw WorldPointsProcessorError.unableToProcessBufferData
//            }
//            worldPointsBufferPtr.copyMemory(
//                from: baseAddress, byteCount: MemoryLayout<WorldPointGridCell>.stride * gridCapacity
//            )
//        }
//        var params = SurfaceNormalForPointGridParams(
//            minStep: UInt32(minStep), maxStep: UInt32(maxStep), eps: eps,
//            longitudinalVector: simd_float2(projectedPlane.firstVector.1 - projectedPlane.firstVector.0),
//            lateralVector: simd_float2(projectedPlane.secondVector.1 - projectedPlane.secondVector.0),
//            normalVector: simd_float2(projectedPlane.normalVector.1 - projectedPlane.normalVector.0),
//            origin: simd_float2(projectedPlane.origin)
//        )
//    }
    
    func getSurfaceNormalsFromWorldPointsCPU(
        worldPointsGrid: WorldPointsGrid,
        projectedPlane: ProjectedPlane,
        minStep: Int = 4,
        maxStep: Int = 10,
        eps: Float = 1e-5
    ) throws -> SurfaceNormalsForPointsGrid {
        let width = worldPointsGrid.width
        let height = worldPointsGrid.height
        
        var surfaceNormalsGrid = SurfaceNormalsForPointsGrid(
            width: width, height: height,
            data: Array(repeating: SurfaceNormalForPointGridCell(
                worldPoint: WorldPoint(p: simd_float3(0, 0, 0)), surfaceNormal: simd_float3(0, 0, 0), isValid: UInt32(0)
            ), count: width * height)
        )
        
        /// Define helper functions for neighbor sampling
        func normalize2D(_ v: SIMD2<Float>) -> SIMD2<Float> {
            let len = simd_length(v)
            return len > 0 ? v / len : SIMD2<Float>(0, 0)
        }
        func makeStep(_ dir: SIMD2<Float>) -> SIMD2<Float> {
            let maxComp = max(abs(dir.x), abs(dir.y))
            if maxComp == 0 { return SIMD2<Float>(0, 0) }
            return dir / maxComp
        }
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
        
        let dirL = normalize2D(projectedPlane.firstVector.1 - projectedPlane.firstVector.0)
        let dirT = normalize2D(projectedPlane.secondVector.1 - projectedPlane.secondVector.0)
        let stepL = makeStep(dirL)
        let stepT = makeStep(dirT)
        
        var validPointCount = 0
        var validSurfaceNormalCount = 0
        let upVector = simd_float3(0, 1, 0)
        var averageNormalYAngles: [Float] = []
        for y in 0..<height {
            for x in 0..<width {
                let cell = worldPointsGrid[x, y]
                guard cell.isValid != 0 else { continue }
//                let originPoint = cell.worldPoint.p
                validPointCount += 1
                
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
                let normalizedNormal = simd_normalize(normal)
                surfaceNormalsGrid[x, y] = SurfaceNormalForPointGridCell(
                    worldPoint: cell.worldPoint,
                    surfaceNormal: normalizedNormal,
                    isValid: UInt32(1)
                )
                validSurfaceNormalCount += 1
                averageNormalYAngles.append(acos(simd_dot(normalizedNormal, upVector)))
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
        print(angleBuckets.map { "\($0.range): \($0.count)" }.joined(separator: ", "))
        return surfaceNormalsGrid
    }
}
