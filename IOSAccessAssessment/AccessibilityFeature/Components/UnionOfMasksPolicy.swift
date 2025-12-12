//
//  UnionOfMasksPolicy.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//

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
        threshold: 0.6,
        defaultFrameWeight: 1.0,
        lastFrameWeight: 2.0
    )
}
