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
        case .metalInitializationError:
            return "Failed to initialize Metal resources for the Segmentation Mesh Pipeline."
        case .metalPipelineCreationError:
            return "Failed to create Metal pipeline state for the Segmentation Mesh Pipeline."
        case .meshPipelineBlitEncoderError:
            return "Failed to create Blit Command Encoder for the Segmentation Mesh Pipeline."
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
    
    init(
        _ context: MeshGPUContext,
        meshSnapshot: MeshSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        color: UIColor, opacity: Float, name: String
    ) throws {
        self.mesh = try self.createMesh(
            meshSnapshot: meshSnapshot,
            segmentationImage: segmentationImage,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
        self.entity = try self.generateEntity(mesh: self.mesh, color: color, opacity: opacity, name: name)
        self.name = name
        self.color = color
        self.opacity = opacity
        
        self.context = context
        guard let kernelFunction = context.device.makeDefaultLibrary()?.makeFunction(name: "processMesh") else {
            throw SegmentationMeshGPUPipelineError.metalInitializationError
        }
        self.pipelineState = try context.device.makeComputePipelineState(function: kernelFunction)
    }
    
    func replace(
        meshSnapshot: MeshSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) throws {
        let clock = ContinuousClock()
        let startTime = clock.now
        let duration = clock.now - startTime
        print("Mesh \(name) updated in \(duration.formatted(.units(allowed: [.milliseconds]))))")
    }
    
    func createMesh(
        meshSnapshot: MeshSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) throws -> LowLevelMesh {
        var descriptor = createDescriptor(meshSnapshot: meshSnapshot)
        let vertexCount = meshSnapshot.meshGPUAnchors.values.reduce(0) { $0 + $1.vertexCount }
        let indexCount = meshSnapshot.meshGPUAnchors.values.reduce(0) { $0 + $1.indexCount }
        descriptor.vertexCapacity = Int(vertexCount) * 2
        descriptor.indexCapacity = Int(indexCount) * 2
        
        let mesh = try LowLevelMesh(descriptor: descriptor)
        
        try update(
            meshSnapshot: meshSnapshot,
            segmentationImage: segmentationImage,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
        return mesh
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
        
        var outVertexBuf = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: maxVerts * meshSnapshot.vertexStride, options: .storageModeShared
        )
        try MeshBufferUtils.ensureCapacity(
            device: self.context.device, buf: &outVertexBuf, requiredBytes: maxVerts * meshSnapshot.vertexStride
        )
        
        var outIndexBuf = try MeshBufferUtils.makeBuffer(
            device: self.context.device, length: maxIndices * meshSnapshot.indexStride, options: .storageModeShared
        )
        try MeshBufferUtils.ensureCapacity(
            device: self.context.device, buf: &outIndexBuf, requiredBytes: maxIndices * meshSnapshot.indexStride
        )
        
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
                throw SegmentationMeshGPUPipelineError.metalPipelineCreationError
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
            
            let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
            let threadGroups = MTLSize(
                width: (anchor.faceCount + threadGroupSize.width - 1) / threadGroupSize.width, height: 1, depth: 1
            )
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            commandEncoder.endEncoding()
        }
        commandBuffer.commit()
    }
    
    func createDescriptor(meshSnapshot: MeshSnapshot) -> LowLevelMesh.Descriptor {
        var d = LowLevelMesh.Descriptor()
        d.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: meshSnapshot.vertexOffset)
        ]
        d.vertexLayouts = [
            .init(bufferIndex: 0, bufferStride: meshSnapshot.vertexStride)
        ]
        // MARK: Assuming uint32 for indices
        d.indexType = .uint32
        return d
    }
    
    func generateEntity(mesh: LowLevelMesh, color: UIColor, opacity: Float, name: String) throws -> ModelEntity {
        let resource = try MeshResource(from: mesh)

        let material = UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))

        let entity = ModelEntity(mesh: resource, materials: [material])
        entity.name = name
        return entity
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
}
