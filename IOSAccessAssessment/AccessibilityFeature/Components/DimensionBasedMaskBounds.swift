//
//  DimensionBasedMaskBounds.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
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
