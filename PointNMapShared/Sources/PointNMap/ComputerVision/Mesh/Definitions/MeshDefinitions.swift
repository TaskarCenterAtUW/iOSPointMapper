//
//  MeshConnectedComponent.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/21/25.
//

import Foundation
import simd
import PointNMapShaderTypes

public struct MeshContents: Sendable {
    public var positions: [packed_float3]
    public var indices: [UInt32]
    public var classifications: [UInt8]? = nil
    public var colorR8: Int
    public var colorG8: Int
    public var colorB8: Int
    
    /// - Warning: Ideally, this property should be avoided for performance reasons.
    public var polygons: [MeshPolygon] {
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
    
    /// TODO: The efficiency of this can be improved through GPU acceleration if needed.
    public var triangles: [MeshTriangle] {
        var result: [MeshTriangle] = []
        for i in stride(from: 0, to: indices.count, by: 3) {
            let i0 = Int(indices[i])
            let i1 = Int(indices[i + 1])
            let i2 = Int(indices[i + 2])
            let polygon = MeshTriangle(
                a: positions[i0], b: positions[i1], c: positions[i2]
            )
            result.append(polygon)
        }
        return result
    }
}

/// - Warning: Ideally, this struct should be avoided for performance reasons. It is recommended to use the `MeshContents` properties directly for efficient processing.
public struct MeshPolygon: Sendable {
    public let v0: simd_float3
    public let v1: simd_float3
    public let v2: simd_float3
    
    public let index0: Int
    public let index1: Int
    public let index2: Int
    
    public var centroid: simd_float3 {
        return (v0 + v1 + v2) / 3.0
    }
    
    public var vertices: [simd_float3] {
        return [v0, v1, v2]
    }
    
    public var area: Float {
        let edge1 = v1 - v0
        let edge2 = v2 - v0
        let crossProduct = simd_cross(edge1, edge2)
        return simd_length(crossProduct) / 2.0
    }
    
    public var normal: simd_float3 {
        let edge1 = v1 - v0
        let edge2 = v2 - v0
        return simd_normalize(simd_cross(edge1, edge2))
    }
}

/**
    Enum representing the dimensions of a mesh.
 */
public enum MeshDimension: CaseIterable, Codable, Sendable {
    /// The X dimension. Horizontal axis. Matches the latitude direction as measured by Location services.
    case x
    /// The Y dimension. Vertical axis.
    case y
    /// The Z dimension. Horizontal axis. Matches the longitude direction as measured by Location services.
    case z
    
    /**
        Provides the index corresponding to the dimension.
     */
    public var index: Int {
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
