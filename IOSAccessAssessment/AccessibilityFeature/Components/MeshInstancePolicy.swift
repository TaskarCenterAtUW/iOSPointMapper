//
//  MeshInstancePolicy.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

/**
    Policy for getting instances of an accessibility feature from mesh data
 
    Attributes:
    - clusterDistanceThreshold: Maximum distance between polygons to be considered part of the same cluster
    - minClusterSize: Minimum number of polygons for a cluster to be considered valid
    - meshClusteringDimensions: Dimensions along which clustering is performed
    - maxClustersToConsider: Maximum number of clusters to consider; if nil, all clusters are considered
 
    TODO: Instead of using only the number of polygons for minClusterSize, we can also consider using the total area of the polygons in the cluster.
 */
struct MeshInstancePolicy: Sendable, Codable, Equatable, Hashable {
    let clusterDistanceThreshold: Float
    let minClusterSize: Int
    let meshClusteringDimensions: Set<MeshDimension>
    
    let maxClustersToConsider: Int?
    
    init(
        clusterDistanceThreshold: Float, minClusterSize: Int,
        meshClusteringDimensions: Set<MeshDimension>, maxClustersToConsider: Int? = nil
    ) {
        self.clusterDistanceThreshold = clusterDistanceThreshold
        self.minClusterSize = minClusterSize
        self.meshClusteringDimensions = meshClusteringDimensions
        self.maxClustersToConsider = maxClustersToConsider
    }
}

extension MeshInstancePolicy {
    static let `default` = MeshInstancePolicy(
        clusterDistanceThreshold: 0.05,
        minClusterSize: 10,
        meshClusteringDimensions: Set(MeshDimension.allCases),
        maxClustersToConsider: nil
    )
}
