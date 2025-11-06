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
        self.mesh = try MeshGPURecord.createMesh(
            meshSnapshot: meshSnapshot,
            segmentationImage: segmentationImage,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
        self.entity = try MeshGPURecord.generateEntity(mesh: self.mesh, color: color, opacity: opacity, name: name)
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
    
    static func createMesh(
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
            mesh: mesh, meshSnapshot: meshSnapshot,
            segmentationImage: segmentationImage,
            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
        return mesh
    }
    
    static func update(
        mesh: LowLevelMesh,
        meshSnapshot: MeshSnapshot,
        segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) throws {
        guard let segmentationPixelBuffer = segmentationImage.pixelBuffer else {
            throw MeshGPURecordError.emptySegmentation
        }
    }
    
    static func createDescriptor(meshSnapshot: MeshSnapshot) -> LowLevelMesh.Descriptor {
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
    
    nonisolated static func vertexSize() -> Int {
        return MemoryLayout<Float>.stride * 3
    }
    
    nonisolated static func indexSize() -> Int {
        return MemoryLayout<UInt32>.stride
    }
    
    static func generateEntity(mesh: LowLevelMesh, color: UIColor, opacity: Float, name: String) throws -> ModelEntity {
        let resource = try MeshResource(from: mesh)

        let material = UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))

        let entity = ModelEntity(mesh: resource, materials: [material])
        entity.name = name
        return entity
    }
}
