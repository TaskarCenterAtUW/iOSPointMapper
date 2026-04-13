//
//  CrossSlopeExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/2/26.
//

import SwiftUI
import CoreLocation

extension AttributeEstimationPipeline {
    func calculateCrossSlope(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        let isMeshEnabled: Bool = self.captureMeshData != nil
        if isMeshEnabled {
            return try self.calculateCrossSlopeFromMesh(accessibilityFeature: accessibilityFeature)
        }
        return try self.calculateCrossSlopeFromImage(accessibilityFeature: accessibilityFeature)
    }
    
    func calculateCrossSlopeFromImage(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        let worldPoints: [WorldPoint] = try self.prerequisiteCache.worldPoints ?? self.getWorldPoints(
            accessibilityFeature: accessibilityFeature
        )
        let alignedPlane: Plane = try self.prerequisiteCache.pointAlignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, worldPoints: worldPoints
        )
        let crossVector = simd_normalize(alignedPlane.secondVector)
        let gravityVector = SIMD3<Float>(0, 1, 0)
        let rise = simd_dot(crossVector, gravityVector)
        let crossHorizontalVector = crossVector - (rise * gravityVector)
        let run = simd_length(crossHorizontalVector)
        let slopeRadians = atan2(rise, run)
        let slopeDegrees: Double = Double(abs(slopeRadians * (180.0 / .pi)))
        
        guard let crossSlopeAttributeValue = AccessibilityFeatureAttribute.crossSlope.value(from: slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return crossSlopeAttributeValue
    }
    
    func calculateCrossSlopeFromMesh(
        accessibilityFeature: EditableAccessibilityFeature
    ) throws -> AccessibilityFeatureAttribute.Value {
        /// TODO: For optimization, replace the usage of meshPolygons with meshTriangles (GPU-based)
        let meshPolygons: [MeshPolygon] = try self.prerequisiteCache.meshPolygons ?? self.getMeshContents(
            accessibilityFeature: accessibilityFeature
        ).polygons
        let alignedPlane: Plane = try self.prerequisiteCache.meshAlignedPlane ?? self.calculateAlignedPlane(
            accessibilityFeature: accessibilityFeature, meshPolygons: meshPolygons
        )
        let crossVector = simd_normalize(alignedPlane.secondVector)
        let gravityVector = SIMD3<Float>(0, 1, 0)
        let rise = simd_dot(crossVector, gravityVector)
        let crossHorizontalVector = crossVector - (rise * gravityVector)
        let run = simd_length(crossHorizontalVector)
        let slopeRadians = atan2(rise, run)
        let slopeDegrees: Double = Double(abs(slopeRadians * (180.0 / .pi)))
        
        guard let crossSlopeAttributeValue = AccessibilityFeatureAttribute.crossSlope.value(from: slopeDegrees) else {
            throw AttributeEstimationPipelineError.attributeAssignmentError
        }
        return crossSlopeAttributeValue
    }
}
