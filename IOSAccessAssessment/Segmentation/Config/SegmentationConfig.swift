//
//  SegmentationClass.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import CoreImage

struct DimensionBasedMaskBounds {
    var minX: Float
    var maxX: Float
    var minY: Float
    var maxY: Float
}

struct SegmentationClass {
    let name: String // Name of the segmentation class
    let grayscaleValue: Float // Grayscale value output for the segmentation class, by the relevant segmentation model
    let labelValue: UInt8 // Pre-defined label of the segmentation class
    let color: CIColor // Color to be assigned for visualization of the segmentation class during post-processing
    let isWay: Bool // Flag to indicate if the class is a road or path
    let bounds: DimensionBasedMaskBounds? // Optional bounds for the segmentation class
    
    // Constants for union of masks
    let unionOfMasksThreshold: Float // Minimum number of frames that need to have a class label for it to be considered valid
    let defaultFrameUnionWeight: Float // Weight for the default frame when calculating the union of masks
    let lastFrameUnionWeight: Float // Weight for the last frame when calculating the union of masks
    
    init(name: String, grayscaleValue: Float, labelValue: UInt8, color: CIColor,
         isWay: Bool = false, bounds: DimensionBasedMaskBounds? = nil,
         unionOfMasksThreshold: Float = 3, defaultFrameWeight: Float = 1, lastFrameWeight: Float = 2) {
        self.name = name
        self.grayscaleValue = grayscaleValue
        self.labelValue = labelValue
        self.color = color
        self.isWay = isWay
        self.bounds = bounds
        self.unionOfMasksThreshold = unionOfMasksThreshold
        self.defaultFrameUnionWeight = defaultFrameWeight
        self.lastFrameUnionWeight = lastFrameWeight
    }
}

struct SegmentationClassConfig {
    let modelURL: URL?
    let classes: [SegmentationClass]
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

enum SegmentationConfig {
    /// Configurations for the segmentation model. Added in separate files.
}
