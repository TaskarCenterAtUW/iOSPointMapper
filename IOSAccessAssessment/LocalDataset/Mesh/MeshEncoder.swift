//
//  MeshEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/9/26.
//

import Foundation
import Accelerate
import ARKit
import RealityKit

struct MeshBundle {
    var meshAnchors: [ARMeshAnchor] = []
    
    let anchorEntity: AnchorEntity
    var modelEntity: ModelEntity
    var lastUpdated: TimeInterval
    var aabbCenter: SIMD3<Float> = .zero
    var aabbExtents: SIMD3<Float> = .zero
    
    var faceCount: Int = 0
    var meanNormal: SIMD3<Float> = .zero
    var assignedColor: UIColor = .green
}

struct MeshPlyContents {
    var positions: [SIMD3<Float>]
    var indices: [UInt32]
    var colorR8: Int
    var colorG8: Int
    var colorB8: Int
}

class MeshEncoder {
    private var baseDirectory: URL

    init(outDirectory: URL) throws {
        self.baseDirectory = outDirectory
        try FileManager.default.createDirectory(at: self.baseDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
    }

    func save(meshBundle: MeshBundle, fileName: String = "mesh") {
        print("Saving mesh to PLY file: \(fileName).ply")
        var ply: String
        
        let modelEntity = meshBundle.modelEntity
        do {
            let modelPly: MeshPlyContents = try getPlyForEntity(modelEntity, vertexColor: UIColor.white)
            ply = generatePlyContent([modelPly], includeColor: true)
        } catch {
            print("Error encoding full mesh to PLY: \(error.localizedDescription)")
            return
        }
        
        do {
            let path = baseDirectory.appendingPathComponent(fileName, isDirectory: false).appendingPathExtension("ply")
            
            try ply.data(using: .utf8)?.write(to: path, options: .atomic)
        } catch {
            print("Error writing PLY file: \(error.localizedDescription)")
        }
    }
    
    func getPlyForEntity(
        _ entity: ModelEntity,
        bakeWorldTransform: Bool = true,
        vertexColor: UIColor? = nil
    ) throws -> MeshPlyContents {
        guard let model = entity.model else {
            status = .encodingError
            print("ModelEntity has no model.")
            throw NSError(domain: "MeshEncoder", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelEntity has no model."])
        }
        let contents = model.mesh.contents
        
        var r8 = 255, g8 = 255, b8 = 255
        if let color = vertexColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            r8 = Int(r * 255)
            g8 = Int(g * 255)
            b8 = Int(b * 255)
        }
        
        let worldTransform = entity.transformMatrix(relativeTo: nil)
        
        // Gather vertices & indices across all instances/parts
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        positions.reserveCapacity(64_000)
        indices.reserveCapacity(64_000)
        
        var vertexBase: UInt32 = 0
        
        for instance in contents.instances {
            // Instance’s transform relative to the entity
            let instanceTransform = instance.transform
            let toWorld = bakeWorldTransform
                ? worldTransform * instanceTransform
                : instanceTransform
            
            // Each instance references a model by index
            let modelRef = contents.models[instance.model]
            guard let modelRef = modelRef else {
                print("Model reference is nil for instance.")
                continue
            }
            for part in modelRef.parts {
                // Read attributes
                let pos: [SIMD3<Float>] = part[MeshBuffers.positions]?.elements ?? []
                let tris: [UInt32] = part.triangleIndices?.elements.map { UInt32($0) } ?? []
                
                // Transform positions if requested
                if bakeWorldTransform {
                    let transformed = pos.map { p -> SIMD3<Float> in
                        let hp = SIMD4<Float>(p, 1)
                        let wp = toWorld * hp
                        return SIMD3<Float>(wp.x, wp.y, wp.z)
                    }
                    positions.append(contentsOf: transformed)
                } else {
                    positions.append(contentsOf: pos)
                }
                
                // Rebase indices to this part’s vertex offset
                indices.append(contentsOf: tris.map { $0 + vertexBase })
                vertexBase += UInt32(pos.count)
            }
        }
        
        guard !positions.isEmpty, !indices.isEmpty else {
            status = .encodingError
            print("No vertex or index data found in ModelEntity.")
            throw NSError(domain: "MeshEncoder", code: 2, userInfo: [NSLocalizedDescriptionKey: "No vertex or index data found in ModelEntity."])
        }
        
        return MeshPlyContents(
            positions: positions, indices: indices,
            colorR8: r8, colorG8: g8, colorB8: b8
        )
    }
    
    func generatePlyContent(
        _ plyContents: [MeshPlyContents],
        includeColor: Bool = true
    ) -> String {
        var ply = ""
        ply += "ply\nformat ascii 1.0\n"
        ply += "comment generated by RealityKit exporter\n"
        
        let totalVertices = plyContents.reduce(0) { $0 + $1.positions.count }
        let totalFaces = plyContents.reduce(0) { $0 + ($1.indices.count / 3) }
        print("Total Faces: \(totalFaces), Total Vertices: \(totalVertices)")
        ply += "element vertex \(totalVertices)\n"
        ply += "property float x\nproperty float y\nproperty float z\n"
        ply += "element face \(totalFaces)\nproperty list uchar int vertex_indices\n"
        if includeColor {
            ply += "property uchar red\nproperty uchar green\nproperty uchar blue\n"
        }
        ply += "end_header\n"
        
        for content in plyContents {
            for pos in content.positions {
                ply += "\(pos.x) \(pos.y) \(pos.z)\n"
            }
        }
        
        if includeColor {
            for content in plyContents {
                print("Mesh Color: \(content.colorR8), \(content.colorG8), \(content.colorB8)")
                let faceCount = content.indices.count / 3
                print("Face Count: \(faceCount)")
                for f in stride(from: 0, to: content.indices.count, by: 3) {
                    let i0 = content.indices[f]
                    let i1 = content.indices[f + 1]
                    let i2 = content.indices[f + 2]
                    ply += "3 \(i0) \(i1) \(i2) \(content.colorR8) \(content.colorG8) \(content.colorB8)\n"
                }
            }
        } else {
            for content in plyContents {
                print("Mesh Color: \(content.colorR8), \(content.colorG8), \(content.colorB8)")
                let faceCount = content.indices.count / 3
                print("Face Count: \(faceCount)")
                for f in stride(from: 0, to: content.indices.count, by: 3) {
                    let i0 = content.indices[f]
                    let i1 = content.indices[f + 1]
                    let i2 = content.indices[f + 2]
                    ply += "3 \(i0) \(i1) \(i2)\n"
                }
            }
        }
        
        return ply
    }
}

extension MeshEncoder {
    func save(meshAnchors: [ARMeshAnchor], frameNumber: UUID) {
    }
}
