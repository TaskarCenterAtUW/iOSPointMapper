//
//  VOCClassConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//
import Foundation
import CoreImage

extension SegmentationConfig {
    static let voc: SegmentationClassConfig = SegmentationClassConfig(
        modelURL: Bundle.main.url(forResource: "espnetv2_pascal_256", withExtension: "mlmodelc"),
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
}
