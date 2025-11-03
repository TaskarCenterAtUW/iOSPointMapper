//
//  MeshRecord.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/2/25.
//
import ARKit
import RealityKit

final class MeshRecord {
    let entity: ModelEntity
    let mesh: MeshResource
    // Reused CPU arrays
    var positions: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    var name: String
    
    init(with triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)], color: UIColor, opacity: Float, name: String) throws {
        self.name = name

        var base: UInt32 = 0
        for t in triangles {
            positions.append(t.0); positions.append(t.1); positions.append(t.2)
            indices.append(base); indices.append(base &+ 1); indices.append(base &+ 2)
            base &+= 3
        }
        
        var meshDescriptor = MeshDescriptor(name: name)
        meshDescriptor.positions = .init(positions)
        meshDescriptor.primitives = .triangles(indices)
        self.mesh = try MeshResource.generate(from: [meshDescriptor])

        let material = UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))
        self.entity = ModelEntity(mesh: mesh, materials: [material])
    }
    
    func replace(with triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]) throws {
        // Reuse capacity
        positions.removeAll(keepingCapacity: true)
        indices.removeAll(keepingCapacity: true)
        positions.reserveCapacity(triangles.count * 3)
        indices.reserveCapacity(triangles.count * 3)
        
        var base: UInt32 = 0
        for t in triangles {
            positions.append(t.0); positions.append(t.1); positions.append(t.2)
            indices.append(base); indices.append(base &+ 1); indices.append(base &+ 2)
            base &+= 3
        }
        
        var desc = MeshDescriptor(name: name)
        desc.positions = .init(positions)
        desc.primitives = .triangles(indices)
        
        let newMesh = try MeshResource.generate(from: [desc])
        self.entity.model?.mesh = newMesh
    }
}
