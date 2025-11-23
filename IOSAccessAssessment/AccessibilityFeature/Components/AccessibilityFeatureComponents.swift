//
//  DimensionBasedMaskBounds.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

/**
    Defines the bounds for dimension-based mask filtering
 
    Attributes:
    - minX: Minimum X coordinate (normalized between 0 and 1)
    - maxX: Maximum X coordinate (normalized between 0 and 1)
    - minY: Minimum Y coordinate (normalized between 0 and 1)
    - maxY: Maximum Y coordinate (normalized between 0 and 1)
 */
struct DimensionBasedMaskBounds: Sendable, Codable, Equatable, Hashable {
    let minX: Float
    let maxX: Float
    let minY: Float
    let maxY: Float
}

/**
    Policy for combining segmentation masks across multiple frames
 
    Attributes:
    - threshold: Minimum number of frames that need to have a class label for it to be considered valid
    - defaultFrameWeight: Weight for the default frame when calculating the union of masks
    - lastFrameWeight: Weight for the last frame when calculating the union of masks
 */
struct UnionOfMasksPolicy: Sendable, Codable, Equatable, Hashable {
    let threshold: Float
    let defaultFrameWeight: Float
    let lastFrameWeight: Float
    
    init(threshold: Float, defaultFrameWeight: Float, lastFrameWeight: Float) {
        self.threshold = threshold
        self.defaultFrameWeight = defaultFrameWeight
        self.lastFrameWeight = lastFrameWeight
    }
}

extension UnionOfMasksPolicy {
    static let `default` = UnionOfMasksPolicy(
        threshold: 3,
        defaultFrameWeight: 1,
        lastFrameWeight: 2
    )
}

/**
    Policy for contour detection in segmentation masks
 
    Attributes:
    - epsilon: Factor to determine the approximation accuracy for contour detection
    - perimeterThreshold: Minimum normalized perimeter for a contour to be considered valid
 */
struct ContourDetectionPolicy: Sendable, Codable, Equatable, Hashable {
    let epsilon: Float
    let perimeterThreshold: Float
}

extension ContourDetectionPolicy {
    static let `default` = ContourDetectionPolicy(
        epsilon: 0.01,
        perimeterThreshold: 0.01
    )
}

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
