//
//  DimensionBasedMaskBounds.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

struct DimensionBasedMaskBounds: Sendable, Codable, Equatable {
    var minX: Float
    var maxX: Float
    var minY: Float
    var maxY: Float
}

struct UnionOfMasksPolicy: Sendable, Codable, Equatable {
    let threshold: Float // Minimum number of frames that need to have a class label for it to be considered valid
    let defaultFrameWeight: Float // Weight for the default frame when calculating the union of masks
    let lastFrameWeight: Float // Weight for the last frame when calculating the union of masks
    
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
