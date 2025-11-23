//
//  MeshConnectedComponent.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/21/25.
//

import Foundation
import simd

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

struct MeshCPUPolygon: Sendable {
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
}

