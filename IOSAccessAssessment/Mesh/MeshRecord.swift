//
//  MeshRecord.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/2/25.
//
import ARKit
import RealityKit

/**
    A structure representing a vertex in the mesh with position and color attributes.
 */
@MainActor
struct MeshVertex {
    var position: SIMD3<Float> = .zero
    var color: UInt32 = .zero
}

extension MeshVertex {
    static var vertexAttributes: [LowLevelMesh.Attribute] = [
        .init(semantic: .position, format: .float3, offset: MemoryLayout<Self>.offset(of: \.position)!),
        .init(semantic: .color, format: .uchar4Normalized_bgra, offset: MemoryLayout<Self>.offset(of: \.color)!)
    ]
    
    static var vertexLayouts: [LowLevelMesh.Layout] = [
        .init(bufferIndex: 0, bufferStride: MemoryLayout<Self>.stride)
    ]
    
    static var descriptor: LowLevelMesh.Descriptor {
        var desc = LowLevelMesh.Descriptor()
        desc.vertexAttributes = MeshVertex.vertexAttributes
        desc.vertexLayouts = MeshVertex.vertexLayouts
        desc.indexType = .uint32
        return desc
    }
}

/**
    A record representing a mesh with associated ModelEntity and properties.
 */
@MainActor
final class MeshRecord {
    let entity: ModelEntity
    var mesh: LowLevelMesh
    let name: String
    let color: UIColor
    let opacity: Float
    
    init(with triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)], color: UIColor, opacity: Float, name: String) throws {
        self.mesh = try MeshRecord.generateMesh(with: triangles)
        self.entity = try MeshRecord.generateEntity(mesh: self.mesh, color: color, opacity: opacity, name: name)
        self.name = name
        self.color = color
        self.opacity = opacity
    }
    
    func replace(with triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]) throws {
        let clock = ContinuousClock()
        let startTime = clock.now
        let updateResults = MeshRecord.updateAndCheckReplaceMesh(mesh: self.mesh, with: triangles)
        if updateResults.isReplaced {
            self.mesh = updateResults.mesh
            let resource = try MeshResource(from: mesh)
            self.entity.model?.mesh = resource
        }
        let duration = clock.now - startTime
        print("Mesh \(name) updated in \(duration.formatted(.units(allowed: [.milliseconds]))))")
    }
    
    static func generateMesh(with triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]) throws -> LowLevelMesh {
        var desc = MeshVertex.descriptor
        // Assign capacity based on triangle count (allocate extra space for future updates)
        let vertexCapacity = triangles.count * 3 * 2
        let indexCapacity = triangles.count * 3 * 2
        desc.vertexCapacity = vertexCapacity
        desc.indexCapacity = indexCapacity
        let mesh = try LowLevelMesh(descriptor: desc)
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: MeshVertex.self)
            var vertexIndex = 0
            for triangle in triangles {
                vertices[vertexIndex + 0].position = triangle.0
                vertices[vertexIndex + 1].position = triangle.1
                vertices[vertexIndex + 2].position = triangle.2
                vertexIndex += 3
            }
        }
        mesh.withUnsafeMutableIndices { rawIndices in
            let indices = rawIndices.bindMemory(to: UInt32.self)
            var index = 0
            var vertexBase: UInt32 = 0
            for _ in triangles {
                indices[index + 0] = vertexBase + 0
                indices[index + 1] = vertexBase + 1
                indices[index + 2] = vertexBase + 2
                index += 3
                vertexBase &+= 3
            }
        }
        
        var meshBounds = BoundingBox(min: .zero, max: .zero)
        mesh.withUnsafeBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: MeshVertex.self)
            meshBounds = computeBounds(UnsafeBufferPointer(start: vertices.baseAddress, count: triangles.count * 3), count: triangles.count * 3)
        }
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount: triangles.count * 3,
                topology: .triangle,
                bounds: meshBounds
            )
        ])
        return mesh
    }
    
    static func updateAndCheckReplaceMesh(
        mesh: LowLevelMesh, with triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]
    ) -> (mesh: LowLevelMesh, isReplaced: Bool) {
        var mesh = mesh
        var isReplaced = false
        // Recalculate the capacity if needed
        if (mesh.descriptor.vertexCapacity < triangles.count * 3) || (mesh.descriptor.indexCapacity < triangles.count * 3) {
            isReplaced = true
            var desc = MeshVertex.descriptor
            desc.vertexCapacity = triangles.count * 3 * 2
            desc.indexCapacity = triangles.count * 3 * 2
            mesh = try! LowLevelMesh(descriptor: desc)
        }
        
        mesh.withUnsafeMutableBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: MeshVertex.self)
            var vertexIndex = 0
            for triangle in triangles {
                vertices[vertexIndex + 0].position = triangle.0
                vertices[vertexIndex + 1].position = triangle.1
                vertices[vertexIndex + 2].position = triangle.2
                vertexIndex += 3
            }
        }
        mesh.withUnsafeMutableIndices { rawIndices in
            let indices = rawIndices.bindMemory(to: UInt32.self)
            var index = 0
            var vertexBase: UInt32 = 0
            for _ in triangles {
                indices[index + 0] = vertexBase + 0
                indices[index + 1] = vertexBase + 1
                indices[index + 2] = vertexBase + 2
                index += 3
                vertexBase &+= 3
            }
        }
        
        var meshBounds = BoundingBox(min: .zero, max: .zero)
        mesh.withUnsafeBytes(bufferIndex: 0) { rawBytes in
            let vertices = rawBytes.bindMemory(to: MeshVertex.self)
            meshBounds = computeBounds(UnsafeBufferPointer(start: vertices.baseAddress, count: triangles.count * 3), count: triangles.count * 3)
        }
        mesh.parts.replaceAll([
            LowLevelMesh.Part(
                indexCount: triangles.count * 3,
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
    
    @inline(__always)
    static func computeBounds(_ verts: UnsafeBufferPointer<MeshVertex>, count: Int) -> BoundingBox {
        guard count > 0 else { return BoundingBox(min: .zero, max: .zero) }

        var minV = SIMD3<Float>(  Float.greatestFiniteMagnitude,
                                  Float.greatestFiniteMagnitude,
                                  Float.greatestFiniteMagnitude)
        var maxV = SIMD3<Float>( -Float.greatestFiniteMagnitude,
                                 -Float.greatestFiniteMagnitude,
                                 -Float.greatestFiniteMagnitude)

        for i in 0..<count {
            let p = verts[i].position
            minV = simd_min(minV, p)
            maxV = simd_max(maxV, p)
        }

        // Small padding so tiny numerical changes don’t get culled
        let eps: Float = 0.005
        minV -= SIMD3<Float>(repeating: eps)
        maxV += SIMD3<Float>(repeating: eps)
        return BoundingBox(min: minV,
                           max: maxV)
    }
}
