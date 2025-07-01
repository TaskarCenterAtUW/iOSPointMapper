//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/24/24.
//

import SwiftUI

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

struct SegmentationClassConstants {
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

// Constants related to the supported classes
struct Constants {
    // Supported Classes
    static let VOCConstants: SegmentationClassConstants = SegmentationClassConstants(
        classes: [
//            SegmentationClass(name: "Background", grayscaleValue: 0.0 / 255.0,
//                              labelValue: 0, color: CIColor(red: 0.000, green: 0.000, blue: 0.000),
            SegmentationClass(name: "Aeroplane", grayscaleValue: 12.0 / 255.0, labelValue: 12,
                              color: CIColor(red: 0.500, green: 0.000, blue: 0.000)),
            SegmentationClass(name: "Bicycle", grayscaleValue: 24.0 / 255.0, labelValue: 24,
                              color: CIColor(red: 0.000, green: 0.500, blue: 0.000)),
            SegmentationClass(name: "Bird", grayscaleValue: 36.0 / 255.0, labelValue: 36,
                              color: CIColor(red: 0.500, green: 0.500, blue: 0.000)),
            SegmentationClass(name: "Boat", grayscaleValue: 48.0 / 255.0, labelValue: 48,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.500)),
            SegmentationClass(name: "Bottle", grayscaleValue: 60.0 / 255.0, labelValue: 60,
                              color: CIColor(red: 0.500, green: 0.000, blue: 0.500)),
            SegmentationClass(name: "Bus", grayscaleValue: 72.0 / 255.0, labelValue: 72,
                              color: CIColor(red: 0.000, green: 0.500, blue: 0.500)),
            SegmentationClass(name: "Car", grayscaleValue: 84.0 / 255.0, labelValue: 84,
                              color: CIColor(red: 0.500, green: 0.500, blue: 0.500)),
            SegmentationClass(name: "Cat", grayscaleValue: 96.0 / 255.0, labelValue: 96,
                              color: CIColor(red: 0.250, green: 0.000, blue: 0.000)),
            SegmentationClass(name: "Chair", grayscaleValue: 108.0 / 255.0, labelValue: 108,
                              color: CIColor(red: 0.750, green: 0.000, blue: 0.000)),
            SegmentationClass(name: "Cow", grayscaleValue: 120.0 / 255.0, labelValue: 120,
                              color: CIColor(red: 0.250, green: 0.500, blue: 0.000)),
            SegmentationClass(name: "Diningtable", grayscaleValue: 132.0 / 255.0, labelValue: 132,
                              color: CIColor(red: 0.750, green: 0.500, blue: 0.000)),
            SegmentationClass(name: "Dog", grayscaleValue: 144.0 / 255.0, labelValue: 144,
                              color: CIColor(red: 0.250, green: 0.000, blue: 0.500)),
            SegmentationClass(name: "Horse", grayscaleValue: 156.0 / 255.0, labelValue: 156,
                              color: CIColor(red: 0.750, green: 0.000, blue: 0.500)),
            SegmentationClass(name: "Motorbike", grayscaleValue: 168.0 / 255.0, labelValue: 168,
                              color: CIColor(red: 0.250, green: 0.500, blue: 0.500)),
            SegmentationClass(name: "Person", grayscaleValue: 180.0 / 255.0, labelValue: 180,
                              color: CIColor(red: 0.750, green: 0.500, blue: 0.500),
                              isWay: true, // Temporarily set to true for testing
                              bounds: DimensionBasedMaskBounds(minX: 0.001, maxX: 0.999, minY: 0.1, maxY: 0.5)
                             ),
            SegmentationClass(name: "PottedPlant", grayscaleValue: 192.0 / 255.0, labelValue: 192,
                              color: CIColor(red: 0.000, green: 0.250, blue: 0.000)),
            SegmentationClass(name: "Sheep", grayscaleValue: 204.0 / 255.0, labelValue: 204,
                              color: CIColor(red: 0.500, green: 0.250, blue: 0.000)),
            SegmentationClass(name: "Sofa", grayscaleValue: 216.0 / 255.0, labelValue: 216,
                              color: CIColor(red: 0.000, green: 0.750, blue: 0.000)),
            SegmentationClass(name: "Train", grayscaleValue: 228.0 / 255.0, labelValue: 228,
                              color: CIColor(red: 0.500, green: 0.750, blue: 0.000)),
            SegmentationClass(name: "TV", grayscaleValue: 240.0 / 255.0, labelValue: 240,
                              color: CIColor(red: 0.000, green: 0.250, blue: 0.500))
        ],
        inputSize: CGSize(width: 256, height: 256)
    )
    
    static let CityScapesConstants: SegmentationClassConstants = SegmentationClassConstants(
        classes: [
//            SegmentationClass(name: "Unlabeled", grayscaleValue: 0.0 / 255.0, labelValue: 0,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
//            SegmentationClass(name: "Ego vehicle", grayscaleValue: 1.0 / 255.0, labelValue: 1,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
//            SegmentationClass(name: "Rectification border", grayscaleValue: 2.0 / 255.0, labelValue: 2,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
//            SegmentationClass(name: "Out of roi", grayscaleValue: 3.0 / 255.0, labelValue: 3,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
//            SegmentationClass(name: "Static", grayscaleValue: 4.0 / 255.0, labelValue: 4,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
            SegmentationClass(name: "Dynamic", grayscaleValue: 5.0 / 255.0, labelValue: 5,
                              color: CIColor(red: 0.435, green: 0.290, blue: 0.000)),
            SegmentationClass(name: "Ground", grayscaleValue: 6.0 / 255.0, labelValue: 6,
                              color: CIColor(red: 0.318, green: 0.000, blue: 0.318)),
            SegmentationClass(name: "Road", grayscaleValue: 7.0 / 255.0, labelValue: 7,
                              color: CIColor(red: 0.502, green: 0.251, blue: 0.502),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            SegmentationClass(name: "Sidewalk", grayscaleValue: 8.0 / 255.0, labelValue: 8,
                              color: CIColor(red: 0.957, green: 0.137, blue: 0.910),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            SegmentationClass(name: "Parking", grayscaleValue: 9.0 / 255.0, labelValue: 9,
                              color: CIColor(red: 0.980, green: 0.667, blue: 0.627)),
            SegmentationClass(name: "Rail track", grayscaleValue: 10.0 / 255.0, labelValue: 10,
                              color: CIColor(red: 0.902, green: 0.588, blue: 0.549)),
            SegmentationClass(name: "Building", grayscaleValue: 11.0 / 255.0, labelValue: 11,
                              color: CIColor(red: 0.275, green: 0.275, blue: 0.275)),
            SegmentationClass(name: "Wall", grayscaleValue: 12.0 / 255.0, labelValue: 12,
                              color: CIColor(red: 0.400, green: 0.400, blue: 0.612)),
            SegmentationClass(name: "Fence", grayscaleValue: 13.0 / 255.0, labelValue: 13,
                              color: CIColor(red: 0.745, green: 0.600, blue: 0.600)),
            SegmentationClass(name: "Guard rail", grayscaleValue: 14.0 / 255.0, labelValue: 14,
                              color: CIColor(red: 0.706, green: 0.647, blue: 0.706)),
            SegmentationClass(name: "Bridge", grayscaleValue: 15.0 / 255.0, labelValue: 15,
                              color: CIColor(red: 0.588, green: 0.392, blue: 0.392)),
            SegmentationClass(name: "Tunnel", grayscaleValue: 16.0 / 255.0, labelValue: 16,
                              color: CIColor(red: 0.588, green: 0.470, blue: 0.353)),
            SegmentationClass(name: "Pole", grayscaleValue: 17.0 / 255.0, labelValue: 17,
                              color: CIColor(red: 0.600, green: 0.600, blue: 0.600)),
            SegmentationClass(name: "Polegroup", grayscaleValue: 18.0 / 255.0, labelValue: 18,
                              color: CIColor(red: 0.600, green: 0.600, blue: 0.600)),
            SegmentationClass(name: "Traffic light", grayscaleValue: 19.0 / 255.0, labelValue: 19,
                              color: CIColor(red: 0.980, green: 0.667, blue: 0.118)),
            SegmentationClass(name: "Traffic sign", grayscaleValue: 20.0 / 255.0, labelValue: 20,
                              color: CIColor(red: 0.863, green: 0.863, blue: 0.000)),
            SegmentationClass(name: "Vegetation", grayscaleValue: 21.0 / 255.0, labelValue: 21,
                              color: CIColor(red: 0.420, green: 0.557, blue: 0.137)),
            SegmentationClass(name: "Terrain", grayscaleValue: 22.0 / 255.0, labelValue: 22,
                              color: CIColor(red: 0.596, green: 0.984, blue: 0.596)),
            SegmentationClass(name: "Sky", grayscaleValue: 23.0 / 255.0, labelValue: 23,
                              color: CIColor(red: 0.275, green: 0.510, blue: 0.706)),
            SegmentationClass(name: "Person", grayscaleValue: 24.0 / 255.0, labelValue: 24,
                              color: CIColor(red: 0.863, green: 0.078, blue: 0.235)),
            SegmentationClass(name: "Rider", grayscaleValue: 25.0 / 255.0, labelValue: 25,
                              color: CIColor(red: 1.000, green: 0.000, blue: 0.000)),
            SegmentationClass(name: "Car", grayscaleValue: 26.0 / 255.0, labelValue: 26,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.557)),
            SegmentationClass(name: "Truck", grayscaleValue: 27.0 / 255.0, labelValue: 27,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.275)),
            SegmentationClass(name: "Bus", grayscaleValue: 28.0 / 255.0, labelValue: 28,
                              color: CIColor(red: 0.000, green: 0.235, blue: 0.392)),
            SegmentationClass(name: "Caravan", grayscaleValue: 29.0 / 255.0, labelValue: 29,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.353)),
            SegmentationClass(name: "Trailer", grayscaleValue: 30.0 / 255.0, labelValue: 30,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.431)),
            SegmentationClass(name: "Train", grayscaleValue: 31.0 / 255.0, labelValue: 31,
                              color: CIColor(red: 0.000, green: 0.314, blue: 0.392)),
            SegmentationClass(name: "Motorcycle", grayscaleValue: 32.0 / 255.0, labelValue: 32,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.902)),
            SegmentationClass(name: "Bicycle", grayscaleValue: 33.0 / 255.0, labelValue: 33,
                              color: CIColor(red: 0.467, green: 0.043, blue: 0.125)),
//            SegmentationClass(name: "Bicycle", grayscaleValue: -1 / 255.0, labelValue: -1,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.557))
        ],
        inputSize: CGSize(width: 1024, height: 512)
    )
    
    // Classes for CityScapes dataset (Main training classes)
    static let CityScapesMainConstants: SegmentationClassConstants = SegmentationClassConstants(
        classes: [
            SegmentationClass(name: "Road", grayscaleValue: 0.0 / 255.0, labelValue: 0,
                              color: CIColor(red: 0.502, green: 0.251, blue: 0.502),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            SegmentationClass(name: "Sidewalk", grayscaleValue: 1.0 / 255.0, labelValue: 1,
                              color: CIColor(red: 0.957, green: 0.137, blue: 0.910),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            SegmentationClass(name: "Building", grayscaleValue: 2.0 / 255.0, labelValue: 2,
                              color: CIColor(red: 0.275, green: 0.275, blue: 0.275)),
            SegmentationClass(name: "Wall", grayscaleValue: 3.0 / 255.0, labelValue: 3,
                              color: CIColor(red: 0.400, green: 0.400, blue: 0.612)),
            SegmentationClass(name: "Fence", grayscaleValue: 4.0 / 255.0, labelValue: 4,
                              color: CIColor(red: 0.745, green: 0.600, blue: 0.600)),
            SegmentationClass(name: "Pole", grayscaleValue: 5.0 / 255.0, labelValue: 5,
                              color: CIColor(red: 0.600, green: 0.600, blue: 0.600)),
            SegmentationClass(name: "Traffic light", grayscaleValue: 6.0 / 255.0, labelValue: 6,
                              color: CIColor(red: 0.980, green: 0.667, blue: 0.118)),
            SegmentationClass(name: "Traffic sign", grayscaleValue: 7.0 / 255.0, labelValue: 7,
                              color: CIColor(red: 0.863, green: 0.863, blue: 0.000)),
            SegmentationClass(name: "Vegetation", grayscaleValue: 8.0 / 255.0, labelValue: 8,
                              color: CIColor(red: 0.420, green: 0.557, blue: 0.137)),
            SegmentationClass(name: "Terrain", grayscaleValue: 9.0 / 255.0, labelValue: 9,
                              color: CIColor(red: 0.596, green: 0.984, blue: 0.596)),
            SegmentationClass(name: "Sky", grayscaleValue: 10.0 / 255.0, labelValue: 10,
                              color: CIColor(red: 0.275, green: 0.510, blue: 0.706)),
            SegmentationClass(name: "Person", grayscaleValue: 11.0 / 255.0, labelValue: 11,
                              color: CIColor(red: 0.863, green: 0.078, blue: 0.235)),
            SegmentationClass(name: "Rider", grayscaleValue: 12.0 / 255.0, labelValue: 12,
                              color: CIColor(red: 1.000, green: 0.000, blue: 0.000)),
            SegmentationClass(name: "Car", grayscaleValue: 13.0 / 255.0, labelValue: 13,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.557)),
            SegmentationClass(name: "Truck", grayscaleValue: 14.0 / 255.0, labelValue: 14,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.275)),
            SegmentationClass(name: "Bus", grayscaleValue: 15.0 / 255.0, labelValue: 15,
                              color: CIColor(red: 0.000, green: 0.235, blue: 0.392)),
            SegmentationClass(name: "Train", grayscaleValue: 16.0 / 255.0, labelValue: 16,
                              color: CIColor(red: 0.000, green: 0.314, blue: 0.392)),
            SegmentationClass(name: "Motorcycle", grayscaleValue: 17.0 / 255.0, labelValue: 17,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.902)),
            SegmentationClass(name: "Bicycle", grayscaleValue: 18.0 / 255.0, labelValue: 18,
                              color: CIColor(red: 0.467, green: 0.043, blue: 0.125))
        ],
        inputSize: CGSize(width: 512, height: 256)
    )
    
    static let CocoCustomConstants: SegmentationClassConstants = SegmentationClassConstants(
        classes: [
            SegmentationClass(name: "Road", grayscaleValue: 41.0 / 255.0, labelValue: 41,
                              color: CIColor(red: 0.502, green: 0.251, blue: 0.502),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            SegmentationClass(name: "Sidewalk", grayscaleValue: 35.0 / 255.0, labelValue: 35,
                              color: CIColor(red: 0.957, green: 0.137, blue: 0.910),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            SegmentationClass(name: "Building", grayscaleValue: 19.0 / 255.0, labelValue: 19,
                              color: CIColor(red: 0.275, green: 0.275, blue: 0.275)),
            SegmentationClass(name: "Wall", grayscaleValue: 50.0 / 255.0, labelValue: 50,
                              color: CIColor(red: 0.400, green: 0.400, blue: 0.612)),
            SegmentationClass(name: "Fence", grayscaleValue: 24.0 / 255.0, labelValue: 24,
                              color: CIColor(red: 0.745, green: 0.600, blue: 0.600)),
            SegmentationClass(name: "Pole", grayscaleValue: 5.0 / 255.0, labelValue: 5,
                              color: CIColor(red: 0.600, green: 0.600, blue: 0.600)),
            SegmentationClass(name: "Traffic light", grayscaleValue: 8.0 / 255.0, labelValue: 8,
                              color: CIColor(red: 0.980, green: 0.667, blue: 0.118)),
            SegmentationClass(name: "Traffic sign", grayscaleValue: 11.0 / 255.0, labelValue: 11,
                              color: CIColor(red: 0.863, green: 0.863, blue: 0.000)),
            SegmentationClass(name: "Vegetation", grayscaleValue: 31.0 / 255.0, labelValue: 31,
                              color: CIColor(red: 0.420, green: 0.557, blue: 0.137)),
            SegmentationClass(name: "Terrain", grayscaleValue: 27.0 / 255.0, labelValue: 27,
                              color: CIColor(red: 0.596, green: 0.984, blue: 0.596)),
//            SegmentationClass(name: "Sky", grayscaleValue: 10.0 / 255.0, labelValue: 10,
//                              color: CIColor(red: 0.275, green: 0.510, blue: 0.706)),
            SegmentationClass(name: "Person", grayscaleValue: 1.0 / 255.0, labelValue: 1,
                              color: CIColor(red: 0.863, green: 0.078, blue: 0.235)),
//            SegmentationClass(name: "Rider", grayscaleValue: 1.0 / 255.0, labelValue: 1,
//                              color: CIColor(red: 1.000, green: 0.000, blue: 0.000)),
            SegmentationClass(name: "Car", grayscaleValue: 3.0 / 255.0, labelValue: 3,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.557)),
            SegmentationClass(name: "Truck", grayscaleValue: 12.0 / 255.0, labelValue: 12,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.275)),
            SegmentationClass(name: "Bus", grayscaleValue: 5.0 / 255.0, labelValue: 5,
                              color: CIColor(red: 0.000, green: 0.235, blue: 0.392)),
            SegmentationClass(name: "Train", grayscaleValue: 6.0 / 255.0, labelValue: 6,
                              color: CIColor(red: 0.000, green: 0.314, blue: 0.392)),
            SegmentationClass(name: "Motorcycle", grayscaleValue: 2.0 / 255.0, labelValue: 2,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.902)),
//            SegmentationClass(name: "Bicycle", grayscaleValue: 2.0 / 255.0, labelValue: 2,
//                              color: CIColor(red: 0.467, green: 0.043, blue: 0.125))
        ],
        inputSize: CGSize(width: 640, height: 640)
    )
    
    static let ClassConstants: SegmentationClassConstants = SegmentationClassConstants(
        classes: [
            SegmentationClass(name: "Road", grayscaleValue: 27.0 / 255.0, labelValue: 27,
                              color: CIColor(red: 0.502, green: 0.251, blue: 0.502),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            SegmentationClass(name: "Sidewalk", grayscaleValue: 22.0 / 255.0, labelValue: 22,
                              color: CIColor(red: 0.957, green: 0.137, blue: 0.910),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            SegmentationClass(name: "Building", grayscaleValue: 16.0 / 255.0, labelValue: 16,
                              color: CIColor(red: 0.275, green: 0.275, blue: 0.275)),
            SegmentationClass(name: "Wall", grayscaleValue: 33 / 255.0, labelValue: 33,
                              color: CIColor(red: 0.400, green: 0.400, blue: 0.612)),
            SegmentationClass(name: "Fence", grayscaleValue: 20.0 / 255.0, labelValue: 20,
                              color: CIColor(red: 0.745, green: 0.600, blue: 0.600)),
            SegmentationClass(name: "Pole", grayscaleValue: 21.0 / 255.0, labelValue: 21,
                              color: CIColor(red: 0.600, green: 0.600, blue: 0.600)),
            SegmentationClass(name: "Traffic light", grayscaleValue: 8.0 / 255.0, labelValue: 8,
                              color: CIColor(red: 0.980, green: 0.667, blue: 0.118)),
            SegmentationClass(name: "Traffic sign", grayscaleValue: 10.0 / 255.0, labelValue: 10,
                              color: CIColor(red: 0.863, green: 0.863, blue: 0.000)),
            SegmentationClass(name: "Vegetation", grayscaleValue: 15.0 / 255.0, labelValue: 15,
                              color: CIColor(red: 0.420, green: 0.557, blue: 0.137)),
            SegmentationClass(name: "Terrain", grayscaleValue: 19.0 / 255.0, labelValue: 19,
                              color: CIColor(red: 0.596, green: 0.984, blue: 0.596)),
//            SegmentationClass(name: "Sky", grayscaleValue: 10.0 / 255.0, labelValue: 10,
//                              color: CIColor(red: 0.275, green: 0.510, blue: 0.706)),
            SegmentationClass(name: "Person", grayscaleValue: 1.0 / 255.0, labelValue: 1,
                              color: CIColor(red: 0.863, green: 0.078, blue: 0.235)),
//            SegmentationClass(name: "Rider", grayscaleValue: 1.0 / 255.0, labelValue: 1,
//                              color: CIColor(red: 1.000, green: 0.000, blue: 0.000)),
            SegmentationClass(name: "Car", grayscaleValue: 3.0 / 255.0, labelValue: 3,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.557)),
            SegmentationClass(name: "Truck", grayscaleValue: 12.0 / 255.0, labelValue: 12,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.275)),
            SegmentationClass(name: "Bus", grayscaleValue: 5.0 / 255.0, labelValue: 5,
                              color: CIColor(red: 0.000, green: 0.235, blue: 0.392)),
            SegmentationClass(name: "Train", grayscaleValue: 7.0 / 255.0, labelValue: 7,
                              color: CIColor(red: 0.000, green: 0.314, blue: 0.392)),
            SegmentationClass(name: "Motorcycle", grayscaleValue: 4.0 / 255.0, labelValue: 4,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.902)),
//            SegmentationClass(name: "Bicycle", grayscaleValue: 2.0 / 255.0, labelValue: 2,
//                              color: CIColor(red: 0.467, green: 0.043, blue: 0.125))
        ],
        inputSize: CGSize(width: 640, height: 640)
    )
    
    struct DepthConstants {
        static let inputSize: CGSize = CGSize(width: 518, height: 392)
    }
}

class Counter {
    static let shared = Counter()
    
    private(set) var count = 0
    private(set) var lastFrameTime = Date()
    
    private init() {}
    
    func increment() {
        self.count += 1
    }
    
    func update() {
        self.lastFrameTime = Date()
    }
}
