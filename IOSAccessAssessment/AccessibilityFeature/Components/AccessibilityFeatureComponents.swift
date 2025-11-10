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
