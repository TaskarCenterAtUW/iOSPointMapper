//
//  CityscapesClassConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//
import Foundation
import CoreImage


extension AccessibilityFeatureConfig {
    static let cityscapes: AccessibilityFeatureClassConfig = AccessibilityFeatureClassConfig(
        modelURL: Bundle.main.url(forResource: "bisenetv2", withExtension: "mlmodelc"),
        classes: [
//            AccessibilityFeatureClass(name: "Unlabeled", grayscaleValue: 0.0 / 255.0, labelValue: 0,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
//            AccessibilityFeatureClass(name: "Ego vehicle", grayscaleValue: 1.0 / 255.0, labelValue: 1,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
//            AccessibilityFeatureClass(name: "Rectification border", grayscaleValue: 2.0 / 255.0, labelValue: 2,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
//            AccessibilityFeatureClass(name: "Out of roi", grayscaleValue: 3.0 / 255.0, labelValue: 3,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
//            AccessibilityFeatureClass(name: "Static", grayscaleValue: 4.0 / 255.0, labelValue: 4,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
            AccessibilityFeatureClass(
                id: "dynamic", name: "Dynamic", grayscaleValue: 5.0 / 255.0, labelValue: 5,
                color: CIColor(red: 0.435, green: 0.290, blue: 0.000)
            ),
            AccessibilityFeatureClass(
                id: "ground", name: "Ground", grayscaleValue: 6.0 / 255.0, labelValue: 6,
                color: CIColor(red: 0.318, green: 0.000, blue: 0.318)
            ),
            AccessibilityFeatureClass(
                id: "road", name: "Road", grayscaleValue: 7.0 / 255.0, labelValue: 7,
                color: CIColor(red: 0.502, green: 0.251, blue: 0.502),
                bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5),
                oswPolicy: OSWPolicy(oswElementClass: .Sidewalk), // Temporarily set for testing
            ),
            AccessibilityFeatureClass(
                id: "sidewalk", name: "Sidewalk", grayscaleValue: 8.0 / 255.0, labelValue: 8,
                color: CIColor(red: 0.957, green: 0.137, blue: 0.910),
                bounds: DimensionBasedMaskBounds(
                minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5),
                oswPolicy: OSWPolicy(oswElementClass: .Sidewalk), // Temporarily set for testing
            ),
            AccessibilityFeatureClass(
                id: "parking", name: "Parking", grayscaleValue: 9.0 / 255.0, labelValue: 9,
                color: CIColor(red: 0.980, green: 0.667, blue: 0.627)),
            AccessibilityFeatureClass(
                id: "rail_track", name: "Rail track", grayscaleValue: 10.0 / 255.0, labelValue: 10,
                color: CIColor(red: 0.902, green: 0.588, blue: 0.549)),
            AccessibilityFeatureClass(
                id: "building", name: "Building", grayscaleValue: 11.0 / 255.0, labelValue: 11,
                color: CIColor(red: 0.275, green: 0.275, blue: 0.275)),
            AccessibilityFeatureClass(
                id: "wall", name: "Wall", grayscaleValue: 12.0 / 255.0, labelValue: 12,
                color: CIColor(red: 0.400, green: 0.400, blue: 0.612)),
            AccessibilityFeatureClass(
                id: "fence", name: "Fence", grayscaleValue: 13.0 / 255.0, labelValue: 13,
                color: CIColor(red: 0.745, green: 0.600, blue: 0.600)),
            AccessibilityFeatureClass(
                id: "guard_rail", name: "Guard rail", grayscaleValue: 14.0 / 255.0, labelValue: 14,
                color: CIColor(red: 0.706, green: 0.647, blue: 0.706)),
            AccessibilityFeatureClass(
                id: "bridge", name: "Bridge", grayscaleValue: 15.0 / 255.0, labelValue: 15,
                color: CIColor(red: 0.588, green: 0.392, blue: 0.392)),
            AccessibilityFeatureClass(
                id: "tunnel", name: "Tunnel", grayscaleValue: 16.0 / 255.0, labelValue: 16,
                color: CIColor(red: 0.588, green: 0.470, blue: 0.353)),
            AccessibilityFeatureClass(
                id: "pole", name: "Pole", grayscaleValue: 17.0 / 255.0, labelValue: 17,
                color: CIColor(red: 0.600, green: 0.600, blue: 0.600)),
            AccessibilityFeatureClass(
                id: "polegroup", name: "Polegroup", grayscaleValue: 18.0 / 255.0, labelValue: 18,
                color: CIColor(red: 0.600, green: 0.600, blue: 0.600)),
            AccessibilityFeatureClass(
                id: "traffic_light", name: "Traffic light", grayscaleValue: 19.0 / 255.0, labelValue: 19,
                color: CIColor(red: 0.980, green: 0.667, blue: 0.118)),
            AccessibilityFeatureClass(
                id: "traffic_sign", name: "Traffic sign", grayscaleValue: 20.0 / 255.0, labelValue: 20,
                color: CIColor(red: 0.863, green: 0.863, blue: 0.000)),
            AccessibilityFeatureClass(
                id: "vegetation", name: "Vegetation", grayscaleValue: 21.0 / 255.0, labelValue: 21,
                color: CIColor(red: 0.420, green: 0.557, blue: 0.137)),
            AccessibilityFeatureClass(
                id: "terrain", name: "Terrain", grayscaleValue: 22.0 / 255.0, labelValue: 22,
                color: CIColor(red: 0.596, green: 0.984, blue: 0.596)),
            AccessibilityFeatureClass(
                id: "sky", name: "Sky", grayscaleValue: 23.0 / 255.0, labelValue: 23,
                color: CIColor(red: 0.275, green: 0.510, blue: 0.706)),
            AccessibilityFeatureClass(
                id: "person", name: "Person", grayscaleValue: 24.0 / 255.0, labelValue: 24,
                color: CIColor(red: 0.863, green: 0.078, blue: 0.235)),
            AccessibilityFeatureClass(
                id: "rider", name: "Rider", grayscaleValue: 25.0 / 255.0, labelValue: 25,
                color: CIColor(red: 1.000, green: 0.000, blue: 0.000)),
            AccessibilityFeatureClass(
                id: "car", name: "Car", grayscaleValue: 26.0 / 255.0, labelValue: 26,
                color: CIColor(red: 0.000, green: 0.000, blue: 0.557)),
            AccessibilityFeatureClass(
                id: "truck", name: "Truck", grayscaleValue: 27.0 / 255.0, labelValue: 27,
                color: CIColor(red: 0.000, green: 0.000, blue: 0.275)),
            AccessibilityFeatureClass(
                id: "bus", name: "Bus", grayscaleValue: 28.0 / 255.0, labelValue: 28,
                color: CIColor(red: 0.000, green: 0.235, blue: 0.392)),
            AccessibilityFeatureClass(
                id: "caravan", name: "Caravan", grayscaleValue: 29.0 / 255.0, labelValue: 29,
                color: CIColor(red: 0.000, green: 0.000, blue: 0.353)),
            AccessibilityFeatureClass(
                id: "trailer", name: "Trailer", grayscaleValue: 30.0 / 255.0, labelValue: 30,
                color: CIColor(red: 0.000, green: 0.000, blue: 0.431)),
            AccessibilityFeatureClass(
                id: "train", name: "Train", grayscaleValue: 31.0 / 255.0, labelValue: 31,
                color: CIColor(red: 0.000, green: 0.314, blue: 0.392)),
            AccessibilityFeatureClass(
                id: "motorcycle", name: "Motorcycle", grayscaleValue: 32.0 / 255.0, labelValue: 32,
                color: CIColor(red: 0.000, green: 0.000, blue: 0.902)),
            AccessibilityFeatureClass(
                id: "bicycle", name: "Bicycle", grayscaleValue: 33.0 / 255.0, labelValue: 33,
                color: CIColor(red: 0.467, green: 0.043, blue: 0.125)),
//            AccessibilityFeatureClass(name: "Bicycle", grayscaleValue: -1 / 255.0, labelValue: -1,
//                              color: CIColor(red: 0.000, green: 0.000, blue: 0.557))
        ],
        inputSize: CGSize(width: 1024, height: 512)
    )
}
