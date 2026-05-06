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
public struct ContourDetectionPolicy: Sendable, Codable, Equatable, Hashable {
    public let epsilon: Float
    public let perimeterThreshold: Float
}

public extension ContourDetectionPolicy {
    static let `default` = ContourDetectionPolicy(
        epsilon: 0.01,
        perimeterThreshold: 0.01
    )
}
