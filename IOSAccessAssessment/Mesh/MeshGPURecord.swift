//
//  MeshGPURecord.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/6/25.
//
import ARKit
import RealityKit

@MainActor
final class MeshGPURecord {
    let entity: ModelEntity
    var mesh: LowLevelMesh
    let name: String
    let color: UIColor
    let opacity: Float
    
    let context: MeshGPUContext
    
    init(
        _ context: MeshGPUContext,
        vertexBuffer: MTLBuffer, vertexCount: UInt32,
        indexBuffer: MTLBuffer, indexCount: UInt32,
        color: UIColor, opacity: Float, name: String
    ) throws {
        self.mesh = try MeshGPURecord.createMesh(
            vertexBuffer: vertexBuffer, vertexCount: vertexCount,
            indexBuffer: indexBuffer, indexCount: indexCount
        )
        self.context = context
        self.entity = try MeshGPURecord.generateEntity(mesh: self.mesh, color: color, opacity: opacity, name: name)
        self.name = name
        self.color = color
        self.opacity = opacity
    }
    
    func replace(
        vertexBuffer: MTLBuffer, vertexCount: UInt32,
        indexBuffer: MTLBuffer, indexCount: UInt32
    ) throws {
        let clock = ContinuousClock()
        let startTime = clock.now
        let duration = clock.now - startTime
        print("Mesh \(name) updated in \(duration.formatted(.units(allowed: [.milliseconds]))))")
    }
    
    static func createMesh(
        vertexBuffer: MTLBuffer, vertexCount: UInt32,
        indexBuffer: MTLBuffer, indexCount: UInt32
    ) throws -> LowLevelMesh {
        var descriptor = createDescriptor()
        descriptor.vertexCapacity = Int(vertexCount) * 2
        descriptor.indexCapacity = Int(indexCount) * 2
        
        let mesh = try LowLevelMesh(descriptor: descriptor)
        
        try update(
            mesh: mesh, vertexBuffer: vertexBuffer, vertexCount: vertexCount,
            indexBuffer: indexBuffer, indexCount: indexCount
        )
        return mesh
    }
    
    static func update(
        mesh: LowLevelMesh,
        vertexBuffer: MTLBuffer, vertexCount: UInt32,
        indexBuffer: MTLBuffer, indexCount: UInt32
    ) throws {
    }
    
    static func createDescriptor() -> LowLevelMesh.Descriptor {
        let vertex = MemoryLayout<MeshTriangle>.self
        var d = LowLevelMesh.Descriptor()
        d.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: vertex.offset(of: \.a) ?? 0)
        ]
        d.vertexLayouts = [
            .init(bufferIndex: 0, bufferStride: vertex.stride)
        ]
        // MARK: Assuming uint32 for indices
        d.indexType = .uint32
        return d
    }
    
    static func generateEntity(mesh: LowLevelMesh, color: UIColor, opacity: Float, name: String) throws -> ModelEntity {
        let resource = try MeshResource(from: mesh)

        let material = UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))

        let entity = ModelEntity(mesh: resource, materials: [material])
        entity.name = name
        return entity
    }
}
