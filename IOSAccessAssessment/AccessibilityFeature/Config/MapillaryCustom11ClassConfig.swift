//
//  CocoCustomClassConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//
import Foundation
import CoreImage

extension AccessibilityFeatureConfig {
    static let mapillaryCustom11Config: AccessibilityFeatureClassConfig = AccessibilityFeatureClassConfig(
        modelURL: Bundle.main.url(forResource: "bisenetv2_11_640_640", withExtension: "mlmodelc"),
        classes: [
//            AccessibilityFeatureClass(name: "Road", grayscaleValue: 0.0 / 255.0, labelValue: 0,
//                              color: CIColor(red: 0.502, green: 0.251, blue: 0.502),
//                              isWay: true,
//                              bounds: DimensionBasedMaskBounds(
//                              minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5
//                              )),
            AccessibilityFeatureClass(name: "Sidewalk", grayscaleValue: 1.0 / 255.0, labelValue: 1,
                              color: CIColor(red: 0.957, green: 0.137, blue: 0.910),
                              isWay: true,
                              bounds: DimensionBasedMaskBounds(
                                minX: 0.0, maxX: 1.0, minY: 0.1, maxY: 0.5
                              ),
                              meshClassification: [.floor]),
            AccessibilityFeatureClass(name: "Building", grayscaleValue: 2.0 / 255.0, labelValue: 2,
                              color: CIColor(red: 0.275, green: 0.275, blue: 0.275)),
            AccessibilityFeatureClass(name: "Pole", grayscaleValue: 3.0 / 255.0, labelValue: 3,
                              color: CIColor(red: 0.600, green: 0.600, blue: 0.600)),
            AccessibilityFeatureClass(name: "Traffic light", grayscaleValue: 4.0 / 255.0, labelValue: 4,
                              color: CIColor(red: 0.980, green: 0.667, blue: 0.118)),
            AccessibilityFeatureClass(name: "Traffic sign", grayscaleValue: 5.0 / 255.0, labelValue: 5,
                              color: CIColor(red: 0.863, green: 0.863, blue: 0.000)),
            AccessibilityFeatureClass(name: "Vegetation", grayscaleValue: 6.0 / 255.0, labelValue: 6,
                              color: CIColor(red: 0.420, green: 0.557, blue: 0.137)),
            AccessibilityFeatureClass(name: "Terrain", grayscaleValue: 7.0 / 255.0, labelValue: 7,
                              color: CIColor(red: 0.596, green: 0.984, blue: 0.596)),
            
            AccessibilityFeatureClass(name: "Static", grayscaleValue: 8.0 / 255.0, labelValue: 8,
                              color: CIColor(red: 0.863, green: 0.078, blue: 0.235)),
            AccessibilityFeatureClass(name: "Dynamic", grayscaleValue: 9.0 / 255.0, labelValue: 9,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.557)),
            AccessibilityFeatureClass(name: "Background", grayscaleValue: 10.0 / 255.0, labelValue: 10,
                              color: CIColor(red: 0.000, green: 0.000, blue: 0.000)),
        ],
        inputSize: CGSize(width: 640, height: 640)
    )
}
