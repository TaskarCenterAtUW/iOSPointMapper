//
//  AccessibilityFeatureConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import CoreImage
import ARKit

struct AccessibilityFeatureClass {
    let name: String // Name of the accessibility feature class
    
    // Segmentation-related constants
    let grayscaleValue: Float // Grayscale value output for the accessibility feature class, by the relevant segmentation model
    let labelValue: UInt8 // Pre-defined label of the accessibility feature class
    let color: CIColor // Color to be assigned for visualization of the segmentation class during post-processing
    
    let isWay: Bool // Flag to indicate if the class is a road or path
    let bounds: DimensionBasedMaskBounds? // Optional bounds for the segmentation class
    let unionOfMasksPolicy: UnionOfMasksPolicy
    
    // Constants related to mesh
    let meshClassification: [ARMeshClassification]? // Optional mesh classification for the segmentation class
    
    init(name: String, grayscaleValue: Float, labelValue: UInt8, color: CIColor,
         isWay: Bool = false, bounds: DimensionBasedMaskBounds? = nil, unionOfMasksPolicy: UnionOfMasksPolicy = .default,
         meshClassification: [ARMeshClassification]? = nil
    ) {
        self.name = name
        self.grayscaleValue = grayscaleValue
        self.labelValue = labelValue
        self.color = color
        self.isWay = isWay
        self.bounds = bounds
        self.unionOfMasksPolicy = unionOfMasksPolicy
        self.meshClassification = meshClassification
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
