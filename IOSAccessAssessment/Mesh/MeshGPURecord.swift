//
//  MeshGPURecord.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/6/25.
//
import ARKit
import RealityKit

enum MeshGPURecordError: Error, LocalizedError {
    case isProcessingTrue
    case emptySegmentation
    case segmentationTextureError
    case segmentationBufferFormatNotSupported
    case metalInitializationError
    case metalPipelineCreationError
    case meshPipelineBlitEncoderError
    case unexpectedError
    
    var errorDescription: String? {
        switch self {
        case .isProcessingTrue:
            return "The Segmentation Mesh Pipeline is already processing a request."
        case .emptySegmentation:
            return "The Segmentation Image does not contain any valid segmentation data."
        case .segmentationTextureError:
            return "Failed to create Metal texture from the segmentation image."
        case .segmentationBufferFormatNotSupported:
            return "The pixel format of the segmentation image is not supported for Metal texture creation."
        case .metalInitializationError:
            return "Failed to initialize Metal resources for the Segmentation Mesh Creation."
        case .metalPipelineCreationError:
            return "Failed to create Metal pipeline state for the Segmentation Mesh Creation."
        case .meshPipelineBlitEncoderError:
            return "Failed to create Blit Command Encoder for the Segmentation Mesh Creation."
        case .unexpectedError:
            return "An unexpected error occurred in the Segmentation Mesh Pipeline."
        }
    }
}

@MainActor
final class MeshGPURecord {
    let entity: ModelEntity
    var mesh: LowLevelMesh
    let name: String
    let color: UIColor
    let opacity: Float
    
    let context: MeshGPUContext
    let pipelineState: MTLComputePipelineState
    var metalCache: CVMetalTextureCache?
    
    init(
        _ context: MeshGPUContext,
        meshSnapshot: MeshSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        color: UIColor, opacity: Float, name: String
    ) throws {
        self.context = context
        guard let kernelFunction = context.device.makeDefaultLibrary()?.makeFunction(name: "processMesh") else {
            throw MeshGPURecordError.metalInitializationError
        }
        self.pipelineState = try context.device.makeComputePipelineState(function: kernelFunction)
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.context.device, nil, &metalCache) == kCVReturnSuccess else {
            throw MeshGPURecordError.metalInitializationError
        }
        
        self.name = name
        self.color = color
        self.opacity = opacity
        
        let descriptor = MeshGPURecord.createDescriptor(meshSnapshot: meshSnapshot)
        self.mesh = try LowLevelMesh(descriptor: descriptor)
        self.entity = try MeshGPURecord.generateEntity(
            mesh: self.mesh, color: color, opacity: opacity, name: name
        )
        try self.replace(
            meshSnapshot: meshSnapshot,
            segmentationImage: segmentationImage, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
    }
    
    func replace(
        meshSnapshot: MeshSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) throws {
//        let clock = ContinuousClock()
//        let startTime = clock.now
        try self.update(
            meshSnapshot: meshSnapshot,
            segmentationImage: segmentationImage,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
//        let duration = clock.now - startTime
//        print("Mesh \(name) updated in \(duration.formatted(.units(allowed: [.milliseconds]))))")
    }
    
    func update(
        meshSnapshot: MeshSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) throws {
        guard let segmentationPixelBuffer = segmentationImage.pixelBuffer else {
            throw MeshGPURecordError.emptySegmentation
        }
        let meshGPUAnchors = meshSnapshot.meshGPUAnchors
        
        let totalFaceCount = meshGPUAnchors.reduce(0) { $0 + $1.value.faceCount }
        let maxTriangles   = max(totalFaceCount, 1)     // avoid 0-sized buffers
        let maxVerts       = maxTriangles * 3
        let maxIndices     = maxTriangles * 3
        
        // Potential replacement of mesh if capacity exceeded
        var mesh = self.mesh
        if (mesh.descriptor.vertexCapacity < maxVerts) ||
            (mesh.descriptor.indexCapacity < maxIndices) {
            print("MeshGPURecord '\(self.name)' capacity exceeded. Reallocating mesh.")
            let newDescriptor = MeshGPURecord.createDescriptor(meshSnapshot: meshSnapshot)
            mesh = try LowLevelMesh(descriptor: newDescriptor)
            let resource = try MeshResource(from: mesh)
            self.entity.model?.mesh = resource
        }
        
        let outTriCount: MTLBuffer = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        // For debugging
        let debugSlots = Int(3) // MARK: Hard-coded
        let debugBytes = debugSlots * MemoryLayout<UInt32>.stride
        let debugCounter: MTLBuffer = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: debugBytes, options: .storageModeShared
        )
        
        let aabbMinU = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: 3 * MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        let aabbMaxU = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: 3 * MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        do {
            let minPtr = aabbMinU.contents().bindMemory(to: UInt32.self, capacity: 3)
            let maxPtr = aabbMaxU.contents().bindMemory(to: UInt32.self, capacity: 3)
            let fMax: Float = .greatestFiniteMagnitude
            let fMin: Float = -Float.greatestFiniteMagnitude
            let initMin = floatToOrderedUInt(fMax)
            let initMax = floatToOrderedUInt(fMin)
            minPtr[0] = initMin; minPtr[1] = initMin; minPtr[2] = initMin
            maxPtr[0] = initMax; maxPtr[1] = initMax; maxPtr[2] = initMax
        }
        
        // Set up additional parameters
        let viewMatrix = simd_inverse(cameraTransform)
        let imageSize = simd_uint2(UInt32(CVPixelBufferGetWidth(segmentationPixelBuffer)),
                                      UInt32(CVPixelBufferGetHeight(segmentationPixelBuffer)))
        // Set up the Metal command buffer
        guard let commandBuffer = self.context.commandQueue.makeCommandBuffer() else {
            throw MeshGPURecordError.metalPipelineCreationError
        }
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw MeshGPURecordError.meshPipelineBlitEncoderError
        }
        blit.fill(buffer: outTriCount, range: 0..<MemoryLayout<UInt32>.stride, value: 0)
        blit.fill(buffer: debugCounter, range: 0..<debugBytes, value: 0)
        blit.endEncoding()
        let threadGroupSizeWidth = min(self.pipelineState.maxTotalThreadsPerThreadgroup, 256)
        
        let outVertexBuf = mesh.replace(bufferIndex: 0, using: commandBuffer)
        let outIndexBuf = mesh.replaceIndices(using: commandBuffer)
        
        let segmentationTexture = try getSegmentationMTLTexture(segmentationPixelBuffer: segmentationPixelBuffer)
        
        for (_, anchor) in meshSnapshot.meshGPUAnchors {
            guard anchor.faceCount > 0 else { continue }
            
            let hasClass: UInt32 = anchor.classificationBuffer != nil ? 1 : 0
            var params = FaceParams(
                faceCount: UInt32(anchor.faceCount), totalCount: UInt32(totalFaceCount),
                indicesPerFace: 3, hasClass: hasClass,
                anchorTransform: anchor.anchorTransform, cameraTransform: cameraTransform,
                viewMatrix: viewMatrix, intrinsics: cameraIntrinsics, imageSize: imageSize
            )
            guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                throw MeshGPURecordError.metalPipelineCreationError
            }
            commandEncoder.setComputePipelineState(self.pipelineState)
            // Main inputs
            commandEncoder.setBuffer(anchor.vertexBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(anchor.indexBuffer, offset: 0, index: 1)
            commandEncoder.setBuffer(anchor.classificationBuffer ?? nil, offset: 0, index: 2)
            // Main outputs
            commandEncoder.setBuffer(outVertexBuf, offset: 0, index: 3)
            commandEncoder.setBuffer(outIndexBuf,  offset: 0, index: 4)
            commandEncoder.setBuffer(outTriCount,  offset: 0, index: 5)
            
            commandEncoder.setBytes(&params, length: MemoryLayout<FaceParams>.stride, index: 6)
            commandEncoder.setBuffer(aabbMinU, offset: 0, index: 7)
            commandEncoder.setBuffer(aabbMaxU, offset: 0, index: 8)
            commandEncoder.setBuffer(debugCounter, offset: 0, index: 9)
            
            commandEncoder.setTexture(segmentationTexture, index: 0)
            
            let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
            let threadGroups = MTLSize(
                width: (anchor.faceCount + threadGroupSize.width - 1) / threadGroupSize.width, height: 1, depth: 1
            )
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            commandEncoder.endEncoding()
        }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let triCount = outTriCount.contents().bindMemory(to: UInt32.self, capacity: 1).pointee
        // Clamp to capacity (defensive)
        let triangleCount = min(Int(triCount), maxTriangles)
//        let vertexCount   = triangleCount * 3
        let indexCount    = triangleCount * 3

        let minU = aabbMinU.contents().bindMemory(to: UInt32.self, capacity: 3)
        let maxU = aabbMaxU.contents().bindMemory(to: UInt32.self, capacity: 3)
        let aabbMin = SIMD3<Float>(
            orderedUIntToFloat(minU[0]),
            orderedUIntToFloat(minU[1]),
            orderedUIntToFloat(minU[2])
        )
        let aabbMax = SIMD3<Float>(
            orderedUIntToFloat(maxU[0]),
            orderedUIntToFloat(maxU[1]),
            orderedUIntToFloat(maxU[2])
        )
        let bounds: BoundingBox = BoundingBox(min: aabbMin, max: aabbMax)
        
        let debugCountPointer = debugCounter.contents().bindMemory(to: UInt32.self, capacity: debugSlots)
        var debugCountValue: [UInt32] = []
        for i in 0..<debugSlots {
            debugCountValue.append(debugCountPointer.advanced(by: i).pointee)
        }

        
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexOffset: 0,
                indexCount: indexCount,
                topology: .triangle,
                materialIndex: 0,
                bounds: bounds
            )
        ])
        self.mesh = mesh
    }
    
    @inline(__always)
    private func floatToOrderedUInt(_ f: Float) -> UInt32 {
        let u = f.bitPattern
        return (u & 0x8000_0000) != 0 ? ~u : (u | 0x8000_0000)
    }

    @inline(__always)
    private func orderedUIntToFloat(_ u: UInt32) -> Float {
        let raw = (u & 0x8000_0000) != 0 ? (u & ~0x8000_0000) : ~u
        return Float(bitPattern: raw)
    }
    
    @inline(__always)
    private func getSegmentationMTLTexture(segmentationPixelBuffer: CVPixelBuffer) throws -> MTLTexture {
        let width  = CVPixelBufferGetWidth(segmentationPixelBuffer)
        let height = CVPixelBufferGetHeight(segmentationPixelBuffer)
        
        guard let pixelFormat: MTLPixelFormat = segmentationPixelBuffer.metalPixelFormat() else {
            throw MeshGPURecordError.segmentationBufferFormatNotSupported
        }
        
        var segmentationTextureRef: CVMetalTexture?
        guard let metalCache = self.metalCache else {
            throw MeshGPURecordError.metalInitializationError
        }
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            metalCache,
            segmentationPixelBuffer,
            nil,
            pixelFormat,
            width,
            height,
            0,
            &segmentationTextureRef
        )
        guard status == kCVReturnSuccess, let segmentationTexture = segmentationTextureRef,
              let texture = CVMetalTextureGetTexture(segmentationTexture) else {
            throw MeshGPURecordError.segmentationTextureError
        }
        return texture
    }
    
    static func createDescriptor(meshSnapshot: MeshSnapshot) -> LowLevelMesh.Descriptor {
        let vertexCount = meshSnapshot.meshGPUAnchors.values.reduce(0) { $0 + $1.vertexCount }
        let indexCount = meshSnapshot.meshGPUAnchors.values.reduce(0) { $0 + $1.indexCount }
        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: meshSnapshot.vertexOffset)
        ]
        descriptor.vertexLayouts = [
            .init(bufferIndex: 0, bufferStride: meshSnapshot.vertexStride)
        ]
        // MARK: Assuming uint32 for indices
        descriptor.indexType = .uint32
        descriptor.vertexCapacity = vertexCount * 10
        descriptor.indexCapacity = indexCount * 10
        return descriptor
    }
    
    static func generateEntity(mesh: LowLevelMesh, color: UIColor, opacity: Float, name: String) throws -> ModelEntity {
        let resource = try MeshResource(from: mesh)
        var material = UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))
        material.triangleFillMode = .fill
        let entity = ModelEntity(mesh: resource, materials: [material])
        entity.name = name
        return entity
    }
}
