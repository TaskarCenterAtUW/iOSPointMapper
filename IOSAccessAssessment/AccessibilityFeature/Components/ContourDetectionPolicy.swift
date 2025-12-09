//
//  ContourDetectionPolicy.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//

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
