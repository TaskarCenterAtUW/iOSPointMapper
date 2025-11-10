//
//  AccessibilityFeatureConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import CoreImage
import ARKit

struct AccessibilityFeatureClass: Identifiable, Hashable, Sendable, Comparable {
    let id: String
    
    let name: String
    
    // Segmentation-related constants
    // Grayscale value output for the accessibility feature class, by the relevant segmentation model
    let grayscaleValue: Float
    // Pre-defined label of the accessibility feature class
    let labelValue: UInt8
    // Color to be assigned for visualization of the segmentation class during post-processing
    let color: CIColor
    
    // Constants related to mesh
    let meshClassification: Set<ARMeshClassification> // Optional mesh classification for the segmentation class
    
    // Post-Processing related constants
    // Flag to indicate if the class is a road or path
    let isWay: Bool
    // Optional bounds for the segmentation class
    // Is kept optional to prevent unnecessary dimension based masking.
    let bounds: DimensionBasedMaskBounds?
    // Properties for union of masks
    let unionOfMasksPolicy: UnionOfMasksPolicy
    
    let calculatedAttributes: Set<AccessibilityFeatureCalculatedAttribute>
    
    init(id: String, name: String, grayscaleValue: Float, labelValue: UInt8, color: CIColor,
         isWay: Bool = false, bounds: DimensionBasedMaskBounds? = nil, unionOfMasksPolicy: UnionOfMasksPolicy = .default,
         meshClassification: Set<ARMeshClassification> = [],
         calculatedAttributes: Set<AccessibilityFeatureCalculatedAttribute> = []
    ) {
        self.id = id
        self.name = name
        self.grayscaleValue = grayscaleValue
        self.labelValue = labelValue
        self.color = color
        self.isWay = isWay
        self.bounds = bounds
        self.unionOfMasksPolicy = unionOfMasksPolicy
        self.meshClassification = meshClassification
        self.calculatedAttributes = calculatedAttributes
    }
    
    static func < (lhs: AccessibilityFeatureClass, rhs: AccessibilityFeatureClass) -> Bool {
        return lhs.labelValue < rhs.labelValue
    }
}

struct AccessibilityFeatureClassConfig {
    let modelURL: URL?
    let classes: [AccessibilityFeatureClass]
    let inputSize: CGSize
    
    var classNames: [String] {
        return classes.map { $0.name }
    }
    
    var grayscaleValues: [Float] {
        return classes.map { $0.grayscaleValue }
    }
    
    var labels: [UInt8] {
        return classes.map { $0.labelValue }
    }
    
    var labelToClassMap: [UInt8: AccessibilityFeatureClass] {
        var map: [UInt8: AccessibilityFeatureClass] = [:]
        for cls in classes {
            map[cls.labelValue] = cls
        }
        return map
    }
    
    var labelToIndexMap: [UInt8: Int] {
        var map: [UInt8: Int] = [:]
        for (index, cls) in classes.enumerated() {
            map[cls.labelValue] = index
        }
        return map
    }
    
    // Retrieve grayscale-to-class mapping as [UInt8: String]
    var labelToClassNameMap: [UInt8: String] {
        var map: [UInt8: String] = [:]
        for cls in classes {
            map[cls.labelValue] = cls.name
        }
        return map
    }
    
    var colors: [CIColor] {
        return classes.map { $0.color }
    }
    
    var labelToColorMap: [UInt8: CIColor] {
        var map: [UInt8: CIColor] = [:]
        for cls in classes {
            map[cls.labelValue] = cls.color
        }
        return map
    }
}

enum AccessibilityFeatureConfig {
    /// Configurations for the segmentation model. Added in separate files.
}
