//
//  CocoCustomClassConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

extension SegmentationConfig {
    static let cocoCustom35Config: SegmentationClassConfig = SegmentationClassConfig(
        modelURL: Bundle.main.url(forResource: "bisenetv2_53_640_640", withExtension: "mlmodelc"),
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
}
