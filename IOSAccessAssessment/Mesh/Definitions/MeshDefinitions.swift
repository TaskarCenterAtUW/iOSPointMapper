//
//  MeshConnectedComponent.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/21/25.
//

import Foundation
import simd

struct MeshContents: Sendable {
    var positions: [packed_float3]
    var indices: [UInt32]
    var classifications: [UInt8]? = nil
    var colorR8: Int
    var colorG8: Int
    var colorB8: Int
    
    var triangles: [MeshPolygon] {
        var result: [MeshPolygon] = []
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i0 = Int(indices[i])
            let i1 = Int(indices[i + 1])
            let i2 = Int(indices[i + 2])
            let vertices = [i0, i1, i2].map { i in
                let packed_v = positions[i]
                return simd_float3(packed_v.x, packed_v.y, packed_v.z)
            }
            let polygon = MeshPolygon(
                v0: vertices[0],
                v1: vertices[1],
                v2: vertices[2],
                index0: Int(indices[i]),
                index1: Int(indices[i + 1]),
                index2: Int(indices[i + 2])
            )
            result.append(polygon)
        }
        return result
    }
}

struct MeshPolygon: Sendable {
    let v0: simd_float3
    let v1: simd_float3
    let v2: simd_float3
    
    let index0: Int
    let index1: Int
    let index2: Int
    
    var centroid: simd_float3 {
        return (v0 + v1 + v2) / 3.0
    }
    
    var vertices: [simd_float3] {
        return [v0, v1, v2]
    }
    
    var area: Float {
        let edge1 = v1 - v0
        let edge2 = v2 - v0
        let crossProduct = simd_cross(edge1, edge2)
        return simd_length(crossProduct) / 2.0
    }
}

/**
    Enum representing the dimensions of a mesh.
 */
enum MeshDimension: CaseIterable, Codable, Sendable {
    /// The X dimension. Horizontal axis. Matches the latitude direction as measured by Location services.
    case x
    /// The Y dimension. Vertical axis.
    case y
    /// The Z dimension. Horizontal axis. Matches the longitude direction as measured by Location services.
    case z
    
    /**
        Provides the index corresponding to the dimension.
     */
    var index: Int {
        switch self {
        case .x:
            return 0
        case .y:
            return 1
        case .z:
            return 2
        }
    }
}
