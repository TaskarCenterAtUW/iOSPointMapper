//
//  CocoCustomClassConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//
import Foundation
import CoreImage

extension AccessibilityFeatureConfig {
    static let cocoCustom53Config: AccessibilityFeatureClassConfig = AccessibilityFeatureClassConfig(
        modelURL: Bundle.main.url(forResource: "bisenetv2_53_640_640", withExtension: "mlmodelc"),
        classes: [
            AccessibilityFeatureClass(name: "Road", grayscaleValue: 41.0 / 255.0, labelValue: 41,
                              color: CIColor(red: 0.502, green: 0.251, blue: 0.502),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            AccessibilityFeatureClass(name: "Sidewalk", grayscaleValue: 35.0 / 255.0, labelValue: 35,
                              color: CIColor(red: 0.957, green: 0.137, blue: 0.910),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5)),
            AccessibilityFeatureClass(name: "Building", grayscaleValue: 19.0 / 255.0, labelValue: 19,
                              color: CIColor(red: 0.275, green: 0.275, blue: 0.275)),
            AccessibilityFeatureClass(name: "Wall", grayscaleValue: 50.0 / 255.0, labelValue: 50,
                              color: CIColor(red: 0.400, green: 0.400, blue: 0.612)),
            AccessibilityFeatureClass(name: "Fence", grayscaleValue: 24.0 / 255.0, labelValue: 24,
                              color: CIColor(red: 0.745, green: 0.600, blue: 0.600)),
            AccessibilityFeatureClass(name: "Pole", grayscaleValue: 5.0 / 255.0, labelValue: 5,
                              color: CIColor(red: 0.600, green: 0.600, blue: 0.600)),
            AccessibilityFeatureClass(name: "Traffic light", grayscaleValue: 8.0 / 255.0, labelValue: 8,
                              color: CIColor(red: 0.980, green: 0.667, blue: 0.118)),
            AccessibilityFeatureClass(name: "Traffic sign", grayscaleValue: 11.0 / 255.0, labelValue: 11,
                              color: CIColor(red: 0.863, green: 0.863, blue: 0.000)),
            AccessibilityFeatureClass(name: "Vegetation", grayscaleValue: 31.0 / 255.0, labelValue: 31,
                              color: CIColor(red: 0.420, green: 0.557, blue: 0.137)),
            AccessibilityFeatureClass(name: "Terrain", grayscaleValue: 27.0 / 255.0, labelValue: 27,
                              color: CIColor(red: 0.596, green: 0.984, blue: 0.596)),
//            AccessibilityFeatureClass(name: "Sky", grayscaleValue: 10.0 / 255.0, labelValue: 10,
//                              color: CIColor(red: 0.275, green: 0.510, blue: 0.706)),
            AccessibilityFeatureClass(name: "Person", grayscaleValue: 1.0 / 255.0, labelValue: 1,
                              color: CIColor(red: 0.863, green: 0.078, blue: 0.235)),
//            AccessibilityFeatureClass(name: "Rider", grayscaleValue: 1.0 / 255.0, labelValue: 1,
//                              color: CIColor(red: 1.000, green: 0.000, blue: 0.000)),
            AccessibilityFeatureClass(name: "Car", grayscaleValue: 3.0 / 255.0, labelValue: 3,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.557)),
            AccessibilityFeatureClass(name: "Truck", grayscaleValue: 12.0 / 255.0, labelValue: 12,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.275)),
            AccessibilityFeatureClass(name: "Bus", grayscaleValue: 5.0 / 255.0, labelValue: 5,
                              color: CIColor(red: 0.000, green: 0.235, blue: 0.392)),
            AccessibilityFeatureClass(name: "Train", grayscaleValue: 6.0 / 255.0, labelValue: 6,
                              color: CIColor(red: 0.000, green: 0.314, blue: 0.392)),
            AccessibilityFeatureClass(name: "Motorcycle", grayscaleValue: 2.0 / 255.0, labelValue: 2,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.902)),
//            AccessibilityFeatureClass(name: "Bicycle", grayscaleValue: 2.0 / 255.0, labelValue: 2,
//                              color: CIColor(red: 0.467, green: 0.043, blue: 0.125))
        ],
        inputSize: CGSize(width: 640, height: 640)
    )
}
