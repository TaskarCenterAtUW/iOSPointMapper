//
//  SurfaceIntegrityFromImageExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/9/26.
//

import ARKit
import RealityKit
import MetalKit
import simd

extension SurfaceIntegrityProcessor {
    /**
        This function assesses the integrity of the surface based on the angular deviation of surface normals from the plane normal using GPU acceleration. It calculates the proportion of points that deviate beyond a specified angular threshold and determines the integrity status based on whether this proportion exceeds a defined threshold.
     */
    func getSurfaceNormalIntegrityResultFromImage(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol),
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.imagePlaneAngularDeviationThreshold,
        deviantPointProportionThreshold: Float = Constants.SurfaceIntegrityConstants.imageDeviantPointProportionThreshold
    ) throws -> IntegrityStatusDetails {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw SurfaceIntegrityProcessorError.metalPipelineCreationError
        }
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        let gridCapacity = width * height
        
        /// Set up the surface normals buffer
        let surfaceNormalsGridBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<SurfaceNormalsForPointsGridCell>.stride * gridCapacity,
            options: .storageModeShared
        )
        let surfaceNormalsGridBufferPtr = surfaceNormalsGridBuffer.contents()
        try surfaceNormalsForPointsGrid.data.withUnsafeBytes { srcPtr in
            guard let baseAddress = srcPtr.baseAddress else {
                throw SurfaceIntegrityProcessorError.unableToProcessBufferData
            }
            surfaceNormalsGridBufferPtr.copyMemory(
                from: baseAddress, byteCount: MemoryLayout<SurfaceNormalsForPointsGridCell>.stride * gridCapacity
            )
        }
        var widthLocal = UInt32(width)
        var heightLocal: UInt32 = UInt32(height)
        var params = DeviantNormalParams(
            normalVector: plane.normalVector,
            angularDeviationCosThreshold: cos(angularDeviationThreshold * .pi / 180.0),
        )
        let totalValidBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device, length: MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        let totalDeviantBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device, length: MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw SurfaceIntegrityProcessorError.meshPipelineBlitEncoderError
        }
        blit.fill(buffer: totalValidBuffer, range: 0..<MemoryLayout<UInt32>.stride, value: 0)
        blit.fill(buffer: totalDeviantBuffer, range: 0..<MemoryLayout<UInt32>.stride, value: 0)
        blit.endEncoding()
        
        let threadGroupSizeWidth = 256
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SurfaceIntegrityProcessorError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.countPipeline)
        commandEncoder.setBuffer(surfaceNormalsGridBuffer, offset: 0, index: 0)
        commandEncoder.setBytes(&widthLocal, length: MemoryLayout<UInt32>.size, index: 1)
        commandEncoder.setBytes(&heightLocal, length: MemoryLayout<UInt32>.size, index: 2)
        commandEncoder.setBytes(&params, length: MemoryLayout<DeviantNormalParams>.stride, index: 3)
        commandEncoder.setBuffer(totalValidBuffer, offset: 0, index: 4)
        commandEncoder.setBuffer(totalDeviantBuffer, offset: 0, index: 5)
        
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (gridCapacity + threadGroupSize.width - 1) / threadGroupSize.width,
                                   height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let totalValidPoints = totalValidBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee
        let totalDeviantPoints = totalDeviantBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee
        let deviantPointProportion = totalValidPoints > 0 ? Float(totalDeviantPoints) / Float(totalValidPoints) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantPointProportion > deviantPointProportionThreshold ? .compromised : .intact,
            details: "Deviant Point Proportion: \(deviantPointProportion * 100)%, Total Deviant Points: \(totalDeviantPoints), Total Points: \(totalValidPoints)"
        )
        return statusDetails
    }
    
    /**
     This function assesses the integrity of the surface based on the angular deviation of surface normals from the plane normal within the bounding boxes of detected damage using GPU acceleration. It calculates the standard deviation of angular deviations for points within each bounding box and determines the integrity status based on whether this standard deviation exceeds a defined threshold.
     
     - Warning:
     The current implementation runs analysis on each bounding box sequentially, which is inefficient. A more optimal approach would involve either batching the bounding boxes and running them through the GPU in parallel to leverage the full potential of GPU acceleration, or better yet, a single kernel that can handle multiple bounding boxes in one pass, potentially using a more complex data structure to represent the bounding boxes and their corresponding points.
     */
    func getBoundingBoxSurfaceNormalIntegrityResultFromImage(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol),
        boundingBoxAngularStdThreshold: Float = Constants.SurfaceIntegrityConstants.imageBoundingBoxAngularStdThreshold
    ) throws -> IntegrityStatusDetails {
        let totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        for damageDetectionResult in damageDetectionResults {
            let boundsParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let angularStd = try getSurfaceNormalStdDetailsWithinBounds(
                worldPointsGrid: worldPointsGrid,
                plane: plane,
                surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
                bounds: boundsParams
            )
            if angularStd > boundingBoxAngularStdThreshold {
                deviantBoundingBoxes += 1
                boundingBoxDetails += "Bounding Box with label \(damageDetectionResult.label) and confidence \(damageDetectionResult.confidence) has surface normal angular std above threshold. Angular Std: \(angularStd).\n"
            }
        }
        let deviantBoundingBoxProportion = totalBoundingBoxes > 0 ? Float(deviantBoundingBoxes) / Float(totalBoundingBoxes) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantBoundingBoxProportion > 0 ? .compromised : .intact,
            details: "Deviant Bounding Box Proportion: \(deviantBoundingBoxProportion * 100)%, Total Bounding Boxes: \(totalBoundingBoxes), Deviant Bounding Boxes: \(deviantBoundingBoxes). Details: \(boundingBoxDetails)"
        )
        return statusDetails
    }
    
    func getSurfaceNormalStdDetailsWithinBounds(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        bounds: BoundsParams
    ) throws -> Float {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw SurfaceIntegrityProcessorError.metalPipelineCreationError
        }
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        let gridCapacity = width * height
        
        /// Set up the surface normals buffer
        let surfaceNormalsGridBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<SurfaceNormalsForPointsGridCell>.stride * gridCapacity,
            options: .storageModeShared
        )
        let surfaceNormalsGridBufferPtr = surfaceNormalsGridBuffer.contents()
        try surfaceNormalsForPointsGrid.data.withUnsafeBytes { srcPtr in
            guard let baseAddress = srcPtr.baseAddress else {
                throw SurfaceIntegrityProcessorError.unableToProcessBufferData
            }
            surfaceNormalsGridBufferPtr.copyMemory(
                from: baseAddress, byteCount: MemoryLayout<SurfaceNormalsForPointsGridCell>.stride * gridCapacity
            )
        }
        var params = StdNormalParams(
            normalVector: plane.normalVector
        )
        var boundsParams = bounds
        let deviationSumBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device, length: MemoryLayout<Float>.stride, options: .storageModeShared
        )
        let deviationSquaredSumBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device, length: MemoryLayout<Float>.stride, options: .storageModeShared
        )
        let totalValidBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device, length: MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw SurfaceIntegrityProcessorError.meshPipelineBlitEncoderError
        }
        blit.fill(buffer: deviationSumBuffer, range: 0..<MemoryLayout<Float>.stride, value: 0)
        blit.fill(buffer: deviationSquaredSumBuffer, range: 0..<MemoryLayout<Float>.stride, value: 0)
        blit.fill(buffer: totalValidBuffer, range: 0..<MemoryLayout<UInt32>.stride, value: 0)
        blit.endEncoding()
        
        let threadGroupSizeWidth = 256
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SurfaceIntegrityProcessorError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.stdPipeline)
        commandEncoder.setBuffer(surfaceNormalsGridBuffer, offset: 0, index: 0)
        commandEncoder.setBytes(&boundsParams, length: MemoryLayout<BoundsParams>.stride, index: 1)
        commandEncoder.setBytes(&params, length: MemoryLayout<StdNormalParams>.stride, index: 2)
        commandEncoder.setBuffer(deviationSumBuffer, offset: 0, index: 3)
        commandEncoder.setBuffer(deviationSquaredSumBuffer, offset: 0, index: 4)
        commandEncoder.setBuffer(totalValidBuffer, offset: 0, index: 5)
        
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (gridCapacity + threadGroupSize.width - 1) / threadGroupSize.width,
                                   height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let angularDeviationSum = deviationSumBuffer.contents().bindMemory(to: Float.self, capacity: 1).pointee
        let angularDeviationSquaredSum = deviationSquaredSumBuffer.contents().bindMemory(to: Float.self, capacity: 1).pointee
        let totalPoints = totalValidBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee
        
        let angularDeviationMean = angularDeviationSum / Float(totalPoints)
        let angularDeviationVariance = (angularDeviationSquaredSum / Float(totalPoints)) - (angularDeviationMean * angularDeviationMean)
        let angularDeviationStd = sqrt(angularDeviationVariance)
        return angularDeviationStd
    }
    
    
    /**
        This CPU function assesses the integrity of the surface based on the angular deviation of surface normals from the plane normal. It calculates the proportion of points that deviate beyond a specified angular threshold and determines the integrity status based on whether this proportion exceeds a defined threshold.
     */
    func getSurfaceNormalIntegrityResultFromImageCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol),
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.imagePlaneAngularDeviationThreshold,
        deviantPointProportionThreshold: Float = Constants.SurfaceIntegrityConstants.imageDeviantPointProportionThreshold
    ) throws -> IntegrityStatusDetails {
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        let surfaceNormalDetails = getSurfaceNormalDeviationDetailsWithinBoundsCPU(
            worldPointsGrid: worldPointsGrid,
            plane: plane,
            surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
            bounds: BoundsParams(minX: 0, minY: 0, maxX: Float(width - 1), maxY: Float(height - 1)),
            angularDeviationThreshold: angularDeviationThreshold
        )
        let totalDeviantPoints = surfaceNormalDetails.deviantPointCount
        let totalPoints = surfaceNormalDetails.totalPointCount
        
        let deviantPointProportion = totalPoints > 0 ? Float(totalDeviantPoints) / Float(totalPoints) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantPointProportion > deviantPointProportionThreshold ? .compromised : .intact,
            details: "Deviant Point Proportion: \(deviantPointProportion * 100)%, Total Deviant Points: \(totalDeviantPoints), Total Points: \(totalPoints)"
        )
        return statusDetails
    }
    
    /**
        This function assesses the integrity of the surface based on the area of the bounding box of detected damage. It retrieves world points corresponding to the corners of the bounding box, calculates the area formed by these points, and determines the integrity status based on whether this area exceeds a defined threshold.
     
        - Warning:
        The current implementation assumes a simple rectangular area calculation based on the corners of the bounding box, which may not be accurate due to perspective distortion. A more robust approach would involve calculating the actual surface area on the plane corresponding to the bounding box, potentially using a mesh representation of the surface.
        Need to take into account the UI orientation to decide which parallel lines to use for area calculation.
     */
    func getBoundingBoxAreaIntegrityResultFromImageCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol),
        boundingBoxAreaThreshold: Float = Constants.SurfaceIntegrityConstants.imageBoundingBoxAreaThreshold,
        boundingBoxWorldPointRetrievalRadius: Float = 3.0
    ) throws -> IntegrityStatusDetails {
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        
        func getWorldPointForCGPointWithinRadius(point: CGPoint, radius: Float) -> simd_float3? {
            let x = Int(point.x)
            let y = Int(point.y)
            var pointSum = simd_float3(0, 0, 0)
            var validPointCount = 0
            for offsetY in -Int(radius)...Int(radius) {
                for offsetX in -Int(radius)...Int(radius) {
                    let neighborX = x + offsetX
                    let neighborY = y + offsetY
                    guard neighborX >= 0, neighborX < width, neighborY >= 0, neighborY < height else { continue }
                    let worldPointForNeighbor = worldPointsGrid[neighborX, neighborY]
                    if worldPointForNeighbor.isValid == 1 {
                        pointSum += worldPointForNeighbor.worldPoint.p
                        validPointCount += 1
                    }
                }
            }
            if validPointCount == 0 { return nil }
            return pointSum / Float(validPointCount)
        }
        
        func getWorldPointForPixel(x: Int, y: Int) -> simd_float3? {
            guard x >= 0, x < width, y >= 0, y < height else { return nil }
            let worldPointForPixel = worldPointsGrid[x, y]
            return worldPointForPixel.isValid == 1 ? worldPointForPixel.worldPoint.p : nil
        }
        
        /// Get 2 sets of parallel lines and calculate 2 areas and average them to get a more robust area estimation
        /// TODO: The bounding box is more like a trapezoid due to the perspective, but because the orientation of parallel lines is UI orientation-dependent,
        /// we will go with the current approach for simplicity.
        func getBoundingBoxArea(worldPoints: [simd_float3]) -> Float {
            guard worldPoints.count == 4 else { return 0 }
            let xVector1 = worldPoints[1] - worldPoints[0]
            let yVector1 = worldPoints[3] - worldPoints[0]
            let area1 = simd_length(simd_cross(xVector1, yVector1))
            let xVector2 = worldPoints[2] - worldPoints[1]
            let yVector2 = worldPoints[0] - worldPoints[1]
            let area2 = simd_length(simd_cross(xVector2, yVector2))
            return (area1 + area2) / 2.0
        }
        
        let totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        for damageDetectionResult in damageDetectionResults {
            let boundingBoxParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let boudingBoxPoints: [CGPoint] = [
                CGPoint(x: CGFloat(boundingBoxParams.minX), y: CGFloat(boundingBoxParams.minY)),
                CGPoint(x: CGFloat(boundingBoxParams.maxX), y: CGFloat(boundingBoxParams.minY)),
                CGPoint(x: CGFloat(boundingBoxParams.maxX), y: CGFloat(boundingBoxParams.maxY)),
                CGPoint(x: CGFloat(boundingBoxParams.minX), y: CGFloat(boundingBoxParams.maxY))
            ]
            let boundingBoxWorldPoints: [simd_float3] = boudingBoxPoints.compactMap {
                getWorldPointForCGPointWithinRadius(point: $0, radius: boundingBoxWorldPointRetrievalRadius)
            }
            if boundingBoxWorldPoints.count < 4 { continue }
            let boundingBoxArea = getBoundingBoxArea(worldPoints: boundingBoxWorldPoints)
            if boundingBoxArea < boundingBoxAreaThreshold { continue }
            deviantBoundingBoxes += 1
            boundingBoxDetails += "Bounding Box with label \(damageDetectionResult.label) and confidence \(damageDetectionResult.confidence) has area above threshold. Area: \(boundingBoxArea)).\n"
        }
        let deviantBoundingBoxProportion = totalBoundingBoxes > 0 ? Float(deviantBoundingBoxes) / Float(totalBoundingBoxes) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantBoundingBoxProportion > 0 ? .compromised : .intact,
            details: "Deviant Bounding Box Proportion: \(deviantBoundingBoxProportion * 100)%, Total Bounding Boxes: \(totalBoundingBoxes), Deviant Bounding Boxes: \(deviantBoundingBoxes). Details: \(boundingBoxDetails)"
        )
        return statusDetails
    }
    
    func getBoundingBoxSurfaceNormalIntegrityResultFromImageCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol),
        boundingBoxAngularStdThreshold: Float = Constants.SurfaceIntegrityConstants.imageBoundingBoxAngularStdThreshold
    ) throws -> IntegrityStatusDetails {
        let totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        for damageDetectionResult in damageDetectionResults {
            let boundsParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let angularStd = getSurfaceNormalStdDetailsWithinBoundsCPU(
                worldPointsGrid: worldPointsGrid,
                plane: plane,
                surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
                bounds: boundsParams
            )
            if angularStd > boundingBoxAngularStdThreshold {
                deviantBoundingBoxes += 1
                boundingBoxDetails += "Bounding Box with label \(damageDetectionResult.label) and confidence \(damageDetectionResult.confidence) has surface normal angular std above threshold. Angular Std: \(angularStd).\n"
            }
        }
        let deviantBoundingBoxProportion = totalBoundingBoxes > 0 ? Float(deviantBoundingBoxes) / Float(totalBoundingBoxes) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantBoundingBoxProportion > 0 ? .compromised : .intact,
            details: "Deviant Bounding Box Proportion: \(deviantBoundingBoxProportion * 100)%, Total Bounding Boxes: \(totalBoundingBoxes), Deviant Bounding Boxes: \(deviantBoundingBoxes). Details: \(boundingBoxDetails)"
        )
        return statusDetails
    }
    
    private func getSurfaceNormalDeviationDetailsWithinBoundsCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        bounds: BoundsParams,
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.imagePlaneAngularDeviationThreshold
    ) -> (deviantPointCount: Int, totalPointCount: Int) {
        let planeNormal = plane.normalVector
        var totalDeviantPoints = 0
        var totalPoints = 0
        for y in Int(bounds.minY)...Int(bounds.maxY) {
            for x in Int(bounds.minX)...Int(bounds.maxX) {
                let surfaceNormalsForPointsGridCell = surfaceNormalsForPointsGrid[x, y]
                if surfaceNormalsForPointsGridCell.isValid == 0 { continue }
                let surfaceNormal = surfaceNormalsForPointsGridCell.surfaceNormal
                let angularDeviation = getAngularDeviation(planeNormal, surfaceNormal)
                if angularDeviation > angularDeviationThreshold {
                    totalDeviantPoints += 1
                }
                totalPoints += 1
            }
        }
        return (deviantPointCount: totalDeviantPoints, totalPointCount: totalPoints)
    }
    
    private func getSurfaceNormalStdDetailsWithinBoundsCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        bounds: BoundsParams
    ) -> Float {
        let planeNormal = plane.normalVector
        var angularDeviationSum: Float = 0
        var angularDeviationSquaredSum: Float = 0
        var totalPoints = 0
        for y in Int(bounds.minY)...Int(bounds.maxY) {
            for x in Int(bounds.minX)...Int(bounds.maxX) {
                let surfaceNormalsForPointsGridCell = surfaceNormalsForPointsGrid[x, y]
                if surfaceNormalsForPointsGridCell.isValid == 0 { continue }
                let surfaceNormal = surfaceNormalsForPointsGridCell.surfaceNormal
                let angularDeviation = getAngularDeviation(planeNormal, surfaceNormal)
                angularDeviationSum += angularDeviation
                angularDeviationSquaredSum += angularDeviation * angularDeviation
                totalPoints += 1
            }
        }
        guard totalPoints > 0 else { return 0 }
        let angularDeviationMean = angularDeviationSum / Float(totalPoints)
        let angularDeviationVariance = (angularDeviationSquaredSum / Float(totalPoints)) - (angularDeviationMean * angularDeviationMean)
        let angularDeviationStd = sqrt(angularDeviationVariance)
        return angularDeviationStd
    }
}
