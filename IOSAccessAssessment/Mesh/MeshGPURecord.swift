//
//  MeshGPURecord.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/5/25.
//
import ARKit
import RealityKit

extension LowLevelMesh.Descriptor {
    static func packedPositionsOnly() -> LowLevelMesh.Descriptor {
        var d = LowLevelMesh.Descriptor()
        d.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: 0) // xyz at byte 0
        ]
        d.vertexLayouts = [
            .init(bufferIndex: 0, bufferStride: 12)                // packed_float3 stride
        ]
        d.indexType = .uint32
        return d
    }
}

@MainActor
final class MeshGPURecord {
    let entity: ModelEntity
    var mesh: LowLevelMesh
    let name: String
    let color: UIColor
    let opacity: Float
    
    init(
        vertexBuffer: MTLBuffer, vertexCount: UInt32,
        indexBuffer: MTLBuffer, indexCount: UInt32,
        color: UIColor, opacity: Float, name: String
    ) throws {
        self.mesh = try MeshGPURecord.createMesh(
            vertexBuffer: vertexBuffer, vertexCount: vertexCount,
            indexBuffer: indexBuffer, indexCount: indexCount
        )
        self.entity = try MeshRecord.generateEntity(mesh: self.mesh, color: color, opacity: opacity, name: name)
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
        let updateResults = try MeshGPURecord.updateAndCheckReplaceMesh(
            mesh: self.mesh,
            vertexBuffer: vertexBuffer, vertexCount: vertexCount,
            indexBuffer: indexBuffer, indexCount: indexCount
        )
        if updateResults.isReplaced {
            self.mesh = updateResults.mesh
            let resource = try MeshResource(from: mesh)
            self.entity.model?.mesh = resource
        }
        let duration = clock.now - startTime
        print("Mesh \(name) updated in \(duration.formatted(.units(allowed: [.milliseconds]))))")
    }
    
    static func createMesh(
        vertexBuffer: MTLBuffer, vertexCount: UInt32,
        indexBuffer: MTLBuffer, indexCount: UInt32
    ) throws -> LowLevelMesh {
        var descriptor = LowLevelMesh.Descriptor.packedPositionsOnly()
        descriptor.vertexCapacity = Int(vertexCount) * 2
        descriptor.indexCapacity = Int(indexCount) * 2
        let mesh = try LowLevelMesh(descriptor: descriptor)
        
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { dst in
            let src = UnsafeRawBufferPointer(start: vertexBuffer.contents(), count: Int(vertexCount) * 12)
            dst.copyMemory(from: src)
        }
        mesh.withUnsafeMutableIndices { dst in
            let src = UnsafeRawBufferPointer(start: indexBuffer.contents(), count: Int(indexCount) * 4)
            dst.copyMemory(from: src)
        }
        let meshBounds: BoundingBox = BoundingBox(min: SIMD3<Float>(-5, -5, -5), max: SIMD3<Float>(5, 5, 5))
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount: Int(indexCount),
                topology: .triangle,
                bounds: meshBounds
            )
        ])
        return mesh
    }
    
    static func updateAndCheckReplaceMesh(
        mesh: LowLevelMesh,
        vertexBuffer: MTLBuffer, vertexCount: UInt32,
        indexBuffer: MTLBuffer, indexCount: UInt32
    ) throws -> (mesh: LowLevelMesh, isReplaced: Bool) {
        var mesh = mesh
        var isReplaced = false
        if (mesh.descriptor.vertexCapacity < Int(vertexCount)) || (mesh.descriptor.indexCapacity < Int(indexCount)) {
            isReplaced = true
            var descriptor = LowLevelMesh.Descriptor.packedPositionsOnly()
            descriptor.vertexCapacity = Int(vertexCount) * 2
            descriptor.indexCapacity = Int(indexCount) * 2
            mesh = try LowLevelMesh(descriptor: descriptor)
        }
        
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { dst in
            let src = UnsafeRawBufferPointer(start: vertexBuffer.contents(), count: Int(vertexCount) * 12)
            dst.copyMemory(from: src)
        }
        mesh.withUnsafeMutableIndices { dst in
            let src = UnsafeRawBufferPointer(start: indexBuffer.contents(), count: Int(indexCount) * 4)
            dst.copyMemory(from: src)
        }
        let meshBounds: BoundingBox = BoundingBox(min: SIMD3<Float>(-5, -5, -5), max: SIMD3<Float>(5, 5, 5))
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount: Int(indexCount),
                topology: .triangle,
                bounds: meshBounds
            )
        ])
        return (mesh, isReplaced)
    }
    
    static func generateEntity(mesh: LowLevelMesh, color: UIColor, opacity: Float, name: String) throws -> ModelEntity {
        let resource = try MeshResource(from: mesh)

        let material = UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))

        let entity = ModelEntity(mesh: resource, materials: [material])
        entity.name = name
        return entity
    }
}
