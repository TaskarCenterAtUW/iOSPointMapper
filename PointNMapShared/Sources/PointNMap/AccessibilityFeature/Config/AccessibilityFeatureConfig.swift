//
//  AccessibilityFeatureConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import CoreImage
import ARKit

public struct AccessibilityFeatureClass: Identifiable, Hashable, Sendable, Comparable, CustomStringConvertible {
    public let id: String
    public let name: String
    public let kind: AccessibilityFeatureKind
    
    /**
     Segmentation-related constants
     */
    /// Grayscale value output for the accessibility feature class, by the relevant segmentation model
    public let grayscaleValue: Float
    /// Pre-defined label of the accessibility feature class
    public let labelValue: UInt8
    /// Color to be assigned for visualization of the segmentation class during post-processing
    public let color: CIColor
    
    /**
     Constants related to mesh
     */
    /// Optional mesh classification for the segmentation class
    public let meshClassification: Set<ARMeshClassification>
    
    /**
     Post-Processing related Constants.
     */
    /// Optional bounds for the segmentation class. Is kept optional to prevent unnecessary dimension based masking.
    public let bounds: CGRect?
    /// Properties for union of masks
    public let unionOfMasksPolicy: UnionOfMasksPolicy
    /// Properties related to mesh post-processing
    public let meshInstancePolicy: MeshInstancePolicy
    
    /**
     Mapping-related Constants
     */
//    public let oswPolicy: OSWPolicy
    
    public init(
        id: String, name: String, kind: AccessibilityFeatureKind = .default,
        grayscaleValue: Float, labelValue: UInt8, color: CIColor,
        bounds: CGRect? = nil, unionOfMasksPolicy: UnionOfMasksPolicy = .default,
        meshClassification: Set<ARMeshClassification> = [],
        meshInstancePolicy: MeshInstancePolicy = .default,
//        attributes: Set<AccessibilityFeatureAttribute> = [],
//        experimentalAttributes: Set<AccessibilityFeatureAttribute> = [],
//        oswPolicy: OSWPolicy = .default
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.grayscaleValue = grayscaleValue
        self.labelValue = labelValue
        self.color = color
        self.bounds = bounds
        self.unionOfMasksPolicy = unionOfMasksPolicy
        self.meshClassification = meshClassification
        self.meshInstancePolicy = meshInstancePolicy
//        self.attributes = attributes
//        self.experimentalAttributes = experimentalAttributes
//        self.oswPolicy = oswPolicy
    }
    
    public static func < (lhs: AccessibilityFeatureClass, rhs: AccessibilityFeatureClass) -> Bool {
        return lhs.labelValue < rhs.labelValue
    }
    
    public var description: String {
        return "AccessibilityFeatureClass(id: \(id), name: \(name), grayscaleValue: \(grayscaleValue), labelValue: \(labelValue), color: \(color))"
    }
}

public struct AccessibilityFeatureClassConfig {
    public let modelURL: URL?
    public let classes: [AccessibilityFeatureClass]
    public let inputSize: CGSize
    
    public init(modelURL: URL?, classes: [AccessibilityFeatureClass], inputSize: CGSize) {
        self.modelURL = modelURL
        self.classes = classes
        self.inputSize = inputSize
    }
    
    public var classNames: [String] {
        return classes.map { $0.name }
    }
    
    public var grayscaleValues: [Float] {
        return classes.map { $0.grayscaleValue }
    }
    
    public var labels: [UInt8] {
        return classes.map { $0.labelValue }
    }
    
    public var labelToClassMap: [UInt8: AccessibilityFeatureClass] {
        var map: [UInt8: AccessibilityFeatureClass] = [:]
        for cls in classes {
            map[cls.labelValue] = cls
        }
        return map
    }
    
    public var labelToIndexMap: [UInt8: Int] {
        var map: [UInt8: Int] = [:]
        for (index, cls) in classes.enumerated() {
            map[cls.labelValue] = index
        }
        return map
    }
    
    // Retrieve grayscale-to-class mapping as [UInt8: String]
    public var labelToClassNameMap: [UInt8: String] {
        var map: [UInt8: String] = [:]
        for cls in classes {
            map[cls.labelValue] = cls.name
        }
        return map
    }
    
    public var colors: [CIColor] {
        return classes.map { $0.color }
    }
    
    public var labelToColorMap: [UInt8: CIColor] {
        var map: [UInt8: CIColor] = [:]
        for cls in classes {
            map[cls.labelValue] = cls.color
        }
        return map
    }
}

public enum AccessibilityFeatureConfig {
    /// Configurations for the segmentation model. Added in separate files.
}
