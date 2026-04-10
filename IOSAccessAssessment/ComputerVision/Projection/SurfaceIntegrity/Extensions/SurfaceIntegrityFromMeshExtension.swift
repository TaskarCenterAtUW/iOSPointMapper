//
//  SurfaceIntegrityFromMeshExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/9/26.
//

import ARKit
import RealityKit
import MetalKit
import simd

extension SurfaceIntegrityProcessor {
    func getSurfaceNormalIntegrityResultFromMesh(
        meshTriangles: [MeshTriangle],
        plane: Plane,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureMeshDataProtocol),
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.meshPlaneAngularDeviationThreshold,
        deviantPointProportionThreshold: Float = Constants.SurfaceIntegrityConstants.meshDeviantPolygonProportionThreshold
    ) throws -> IntegrityStatusDetails {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw SurfaceIntegrityProcessorError.metalPipelineCreationError
        }
        let count = meshTriangles.count
        
        /// Set up the triangle data buffer
        let meshTriangleBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<MeshTriangle>.stride * count,
            options: .storageModeShared
        )
        let meshTriangleBufferPtr = meshTriangleBuffer.contents()
        try meshTriangles.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                throw SurfaceIntegrityProcessorError.unableToProcessBufferData
            }
            meshTriangleBufferPtr.copyMemory(from: baseAddress, byteCount: MemoryLayout<MeshTriangle>.stride * count)
        }
        var countLocal = UInt32(count)
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
        
        commandEncoder.setComputePipelineState(self.countPolygonPipeline)
        commandEncoder.setBuffer(meshTriangleBuffer, offset: 0, index: 0)
        commandEncoder.setBytes(&countLocal, length: MemoryLayout<UInt32>.stride, index: 1)
        commandEncoder.setBytes(&params, length: MemoryLayout<DeviantNormalParams>.stride, index: 2)
        commandEncoder.setBuffer(totalValidBuffer, offset: 0, index: 3)
        commandEncoder.setBuffer(totalDeviantBuffer, offset: 0, index: 4)
        
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: (count + threadGroupSizeWidth - 1) / threadGroupSizeWidth, height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let totalValidPolygons = totalValidBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee
        let totalDeviantPolygons = totalDeviantBuffer.contents().bindMemory(to: UInt32.self, capacity: 1).pointee
        let deviantPolygonProportion = totalValidPolygons > 0 ? Float(totalDeviantPolygons) / Float(totalValidPolygons) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantPolygonProportion > deviantPointProportionThreshold ? .compromised : .intact,
            details: "Deviant Polygon Proportion: \(deviantPolygonProportion * 100)%, Total Deviant Polygons: \(totalDeviantPolygons), Total Valid Polygons: \(totalValidPolygons)"
        )
        return statusDetails
    }
    
    func getBoundingBoxAreaIntegrityResultFromMesh(
        meshTriangles: [MeshTriangle],
        plane: Plane,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureMeshDataProtocol),
        boundingBoxAreaThreshold: Float = Constants.SurfaceIntegrityConstants.meshBoundingBoxAreaThreshold
    ) throws -> IntegrityStatusDetails {
        let totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        for damageDetectionResult in damageDetectionResults {
            let boundsParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let area = try getAreaWithinBounds(
                meshTriangles: meshTriangles,
                plane: plane,
                bounds: boundsParams
            )
            if area < boundingBoxAreaThreshold { continue }
            deviantBoundingBoxes += 1
            boundingBoxDetails += "Bounding Box with label \(damageDetectionResult.label) and confidence \(damageDetectionResult.confidence) has area above threshold. Area: \(area)).\n"
        }
        let deviantBoundingBoxProportion = totalBoundingBoxes > 0 ? Float(deviantBoundingBoxes) / Float(totalBoundingBoxes) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantBoundingBoxProportion > 0 ? .compromised : .intact,
            details: "Deviant Bounding Box Proportion: \(deviantBoundingBoxProportion * 100)%, Total Bounding Boxes: \(totalBoundingBoxes), Deviant Bounding Boxes: \(deviantBoundingBoxes). Details: \(boundingBoxDetails)"
        )
        return statusDetails
    }
    
    func getBoundingBoxSurfaceNormalIntegrityResultFromMesh(
        meshTriangles: [MeshTriangle],
        plane: Plane,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureMeshDataProtocol),
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.meshPlaneAngularDeviationThreshold,
        boundingBoxAngularStdThreshold: Float = Constants.SurfaceIntegrityConstants.meshBoundingBoxAngularStdThreshold
    ) throws -> IntegrityStatusDetails {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw SurfaceIntegrityProcessorError.metalPipelineCreationError
        }
        let count = meshTriangles.count
    }
    
    func getAreaWithinBounds(
        meshTriangles: [MeshTriangle],
        plane: Plane,
        bounds: BoundsParams
    ) throws -> Float {
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw SurfaceIntegrityProcessorError.metalPipelineCreationError
        }
        let count = meshTriangles.count
        
        /// Set up the triangle data buffer
        let meshTriangleBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device,
            length: MemoryLayout<MeshTriangle>.stride * count,
            options: .storageModeShared
        )
        let meshTriangleBufferPtr = meshTriangleBuffer.contents()
        try meshTriangles.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                throw SurfaceIntegrityProcessorError.unableToProcessBufferData
            }
            meshTriangleBufferPtr.copyMemory(from: baseAddress, byteCount: MemoryLayout<MeshTriangle>.stride * count)
        }
        var countLocal = UInt32(count)
        var boundsParams = bounds
        /// Set up the buffers to hold the area
        let threadGroupSizeWidth = 256
        let numThreadGroups = (count + threadGroupSizeWidth - 1) / threadGroupSizeWidth
        let areaBuffer: MTLBuffer = try MetalBufferUtils.makeBuffer(
            device: self.device, length: MemoryLayout<Float>.stride * numThreadGroups, options: .storageModeShared
        )
        
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw SurfaceIntegrityProcessorError.meshPipelineBlitEncoderError
        }
        blit.fill(buffer: areaBuffer, range: 0..<(MemoryLayout<Float>.stride * numThreadGroups), value: 0)
        blit.endEncoding()
        
        guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SurfaceIntegrityProcessorError.metalPipelineCreationError
        }
        
        commandEncoder.setComputePipelineState(self.areaWithinBoundsPolygonPipeline)
        commandEncoder.setBuffer(meshTriangleBuffer, offset: 0, index: 0)
        commandEncoder.setBytes(&countLocal, length: MemoryLayout<UInt32>.stride, index: 1)
        commandEncoder.setBytes(&boundsParams, length: MemoryLayout<BoundsParams>.stride, index: 2)
        commandEncoder.setBuffer(areaBuffer, offset: 0, index: 3)
        
        let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
        let threadgroups = MTLSize(width: numThreadGroups, height: 1, depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let areaPointer = areaBuffer.contents().bindMemory(to: Float.self, capacity: numThreadGroups)
        var totalArea: Float = 0
        for i in 0..<numThreadGroups {
            totalArea += areaPointer[i]
        }
        return totalArea
    }
    
    func getSurfaceNormalIntegrityResultFromMeshCPU(
        meshPolygons: [MeshPolygon],
        plane: Plane,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureMeshDataProtocol),
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.meshPlaneAngularDeviationThreshold,
        deviantPolygonProportion: Float = Constants.SurfaceIntegrityConstants.meshDeviantPolygonProportionThreshold
    ) throws -> IntegrityStatusDetails {
        let planeNormal = plane.normalVector
        var totalDeviantPolygons = 0
        var totalPolygons = 0
        for meshPolygon in meshPolygons {
            let surfaceNormal = meshPolygon.normal
            let angularDeviation = getAngularDeviation(planeNormal, surfaceNormal)
            if angularDeviation > angularDeviationThreshold {
                totalDeviantPolygons += 1
            }
            totalPolygons += 1
        }
        let deviantPolygonProportion = totalPolygons > 0 ? Float(totalDeviantPolygons) / Float(totalPolygons) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantPolygonProportion > deviantPolygonProportion ? .compromised : .intact,
            details: "Deviant Polygon Proportion: \(deviantPolygonProportion * 100)%, Total Deviant Polygon: \(totalDeviantPolygons), Total Polygons: \(totalPolygons)"
        )
        return statusDetails
    }
    
    func getBoundingBoxAreaIntegrityResultFromMeshCPU(
        meshPolygons: [MeshPolygon],
        plane: Plane,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureMeshDataProtocol),
        boundingBoxAreaThreshold: Float = Constants.SurfaceIntegrityConstants.meshBoundingBoxAreaThreshold
    ) throws -> IntegrityStatusDetails {
        let viewMatrix = captureData.cameraTransform.inverse
        let totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        
        let meshPolygonCentroidPixels: [CGPoint?] = meshPolygons.map { meshPolygon in
            let centroid = meshPolygon.centroid
            return ProjectionUtils.unprojectWorldToPixel(
                worldPoint: centroid,
                viewMatrix: viewMatrix,
                cameraIntrinsics: captureData.cameraIntrinsics,
                imageSize: captureData.originalSize
            )
        }
        
        for damageDetectionResult in damageDetectionResults {
            let boundsParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let minX = Int(boundsParams.minX)
            let maxX = Int(boundsParams.maxX)
            let minY = Int(boundsParams.minY)
            let maxY = Int(boundsParams.maxY)
            var boundingBoxArea: Float = 0.0
            for i in 0..<meshPolygons.count {
                let meshPolygon = meshPolygons[i]
                let centroidPixel = meshPolygonCentroidPixels[i]
                guard let centroidPixel else { continue }
                let centroidPixelX = Int(centroidPixel.x)
                let centroidPixelY = Int(centroidPixel.y)
                guard centroidPixelX >= minX, centroidPixelX <= maxX,
                      centroidPixelY >= minY, centroidPixelY <= maxY else {
                    continue
                }
                boundingBoxArea += meshPolygon.area
            }
            guard boundingBoxArea > boundingBoxAreaThreshold else { continue }
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
    
    func getBoundingBoxSurfaceNormalIntegrityResultFromMeshCPU(
        meshPolygons: [MeshPolygon],
        plane: Plane,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureMeshDataProtocol),
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.meshPlaneAngularDeviationThreshold,
        boundingBoxAngularStdThreshold: Float = Constants.SurfaceIntegrityConstants.meshBoundingBoxAngularStdThreshold
    ) throws -> IntegrityStatusDetails {
        let viewMatrix = captureData.cameraTransform.inverse
        let planeNormal = plane.normalVector
        let totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        
        let meshPolygonCentroidPixels: [CGPoint?] = meshPolygons.map { meshPolygon in
            let centroid = meshPolygon.centroid
            return ProjectionUtils.unprojectWorldToPixel(
                worldPoint: centroid,
                viewMatrix: viewMatrix,
                cameraIntrinsics: captureData.cameraIntrinsics,
                imageSize: captureData.originalSize
            )
        }
        
        for damageDetectionResult in damageDetectionResults {
            let boundsParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let minX = Int(boundsParams.minX)
            let maxX = Int(boundsParams.maxX)
            let minY = Int(boundsParams.minY)
            let maxY = Int(boundsParams.maxY)
            var angularDeviationSum: Float = 0
            var angularDeviationSquaredSum: Float = 0
            var totalPolygons = 0
            for i in 0..<meshPolygons.count {
                let meshPolygon = meshPolygons[i]
                let centroidPixel = meshPolygonCentroidPixels[i]
                guard let centroidPixel else { continue }
                let centroidPixelX = Int(centroidPixel.x)
                let centroidPixelY = Int(centroidPixel.y)
                guard centroidPixelX >= minX, centroidPixelX <= maxX,
                      centroidPixelY >= minY, centroidPixelY <= maxY else {
                    continue
                }
                let surfaceNormal = meshPolygon.normal
                let angularDeviation = getAngularDeviation(planeNormal, surfaceNormal)
                angularDeviationSum += angularDeviation
                angularDeviationSquaredSum += angularDeviation * angularDeviation
                totalPolygons += 1
            }
            guard totalPolygons > 0 else { continue }
            let angularDeviationMean = angularDeviationSum / Float(totalPolygons)
            let angularDeviationVariance = (angularDeviationSquaredSum / Float(totalPolygons)) - (angularDeviationMean * angularDeviationMean)
            let angularDeviationStd = sqrt(angularDeviationVariance)
            if angularDeviationStd > boundingBoxAngularStdThreshold {
                deviantBoundingBoxes += 1
                boundingBoxDetails += "Bounding Box with label \(damageDetectionResult.label) and confidence \(damageDetectionResult.confidence) has surface normal angular std above threshold. Angular Std: \(angularDeviationStd).\n"
            }
        }
        let deviantBoundingBoxProportion = totalBoundingBoxes > 0 ? Float(deviantBoundingBoxes) / Float(totalBoundingBoxes) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantBoundingBoxProportion > 0 ? .compromised : .intact,
            details: "Deviant Bounding Box Proportion: \(deviantBoundingBoxProportion * 100)%, Total Bounding Boxes: \(totalBoundingBoxes), Deviant Bounding Boxes: \(deviantBoundingBoxes). Details: \(boundingBoxDetails)"
        )
        return statusDetails
    }
}
