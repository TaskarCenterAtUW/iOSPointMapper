//
//  MeshClusteringUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/25.
//

import Foundation
import simd

public struct MeshClusteringUtils {
    public static func distanceFunction(polygonA: MeshPolygon, polygonB: MeshPolygon) -> Float {
        return simd_distance(polygonA.centroid, polygonB.centroid)
    }
    
    public static func adjacencyFunction(polygonA: MeshPolygon, polygonB: MeshPolygon, threshold: Float) -> Bool {
        for vertexA in polygonA.vertices {
            for vertexB in polygonB.vertices {
                /// Check if the vertex is the same. We use a small epsilon to account for floating point errors
                if simd_distance(vertexA, vertexB) < 1e-5 {
                    return true
                }
            }
        }
        return simd_distance(polygonA.centroid, polygonB.centroid) < threshold
    }
}
