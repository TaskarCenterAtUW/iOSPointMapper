//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/24/24.
//

import SwiftUI

struct SegmentationClass {
    let name: String // Name of the segmentation class
    let grayscaleValue: Float // Grayscale value output for the segmentation class, by the relevant segmentation model
    let labelValue: UInt8 // Pre-defined label of the segmentation class
    let color: CIColor // Color to be assigned for visualization of the segmentation class during post-processing
}

struct SegmentationClassConstants {
    private let classes: [SegmentationClass]
    private let inputSize: CGSize
    
    init(classes: [SegmentationClass], inputSize: CGSize) {
        self.classes = classes
        self.inputSize = inputSize
    }
    
    func getClasses() -> [SegmentationClass] {
        return classes
    }
    
    func getInputSize() -> CGSize {
        return inputSize
    }
    
    func getClassNames() -> [String] {
        return classes.map { $0.name }
    }
    
    func getGrayscaleValues() -> [Float] {
        return classes.map { $0.grayscaleValue }
    }
    
    // Retrieve grayscale-to-class mapping as [UInt8: String]
    func getGrayscaleToClassMap() -> [UInt8: String] {
        var map: [UInt8: String] = [:]
        for cls in classes {
            map[cls.labelValue] = cls.name
        }
        return map
    }
    
    func getColors() -> [CIColor] {
        return classes.map { $0.color }
    }
}

// Constants related to the supported classes
struct Constants {
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
                              color: CIColor(red: 0.750, green: 0.500, blue: 0.500)),
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
        inputSize: CGSize(width: 1024, height: 1024)
    )
    
    // Supported Classes
    struct ClassConstants {
        
        static let classes = [
//            "Background",
            "Aeroplane", "Bicycle", "Bird", "Boat", "Bottle", "Bus",
            "Car", "Cat", "Chair", "Cow", "Diningtable","Dog", "Horse", "Motorbike",
            "Person", "Pottedplant", "Sheep", "Sofa", "Train", "TV"
        ]
        
        static let grayValues: [Float] = [
//            0,
            12, 24, 36, 48, 60, 72, 84, 96, 108, 120,
            132, 144, 156, 168, 180, 192, 204, 216, 228, 240].map{Float($0)/255.0}
        
        static let grayscaleToClassMap: [UInt8: String] = [
//            0: "Background",
            12: "Aeroplane",
            24: "Bicycle",
            36: "Bird",
            48: "Boat",
            60: "Bottle",
            72: "Bus",
            84: "Car",
            96: "Cat",
            108: "Chair",
            120: "Cow",
            132: "Diningtable",
            144: "Dog",
            156: "Horse",
            168: "Motorbike",
            180: "Person",
            192: "PottedPlant",
            204: "Sheep",
            216: "Sofa",
            228: "Train",
            240: "TV"
        ]
        
        // Note: Do not use black (0, 0, 0) color, as significant portion of object detection relies on
        //  treating black color as no object in a segmentation mask
        static let colors: [CIColor] = [
            CIColor(red: 0.000, green: 0.000, blue: 0.000),
            CIColor(red: 0.500, green: 0.000, blue: 0.000),
            CIColor(red: 0.000, green: 0.500, blue: 0.000),
            CIColor(red: 0.500, green: 0.500, blue: 0.000),
            CIColor(red: 0.000, green: 0.000, blue: 0.500),
            CIColor(red: 0.500, green: 0.000, blue: 0.500),
            CIColor(red: 0.000, green: 0.500, blue: 0.500),
            CIColor(red: 0.500, green: 0.500, blue: 0.500),
            CIColor(red: 0.250, green: 0.000, blue: 0.000),
            CIColor(red: 0.750, green: 0.000, blue: 0.000),
            CIColor(red: 0.250, green: 0.500, blue: 0.000),
            CIColor(red: 0.750, green: 0.500, blue: 0.000),
            CIColor(red: 0.250, green: 0.000, blue: 0.500),
            CIColor(red: 0.750, green: 0.000, blue: 0.500),
            CIColor(red: 0.250, green: 0.500, blue: 0.500),
            CIColor(red: 0.750, green: 0.500, blue: 0.500),
            CIColor(red: 0.000, green: 0.250, blue: 0.000),
            CIColor(red: 0.500, green: 0.250, blue: 0.000),
            CIColor(red: 0.000, green: 0.750, blue: 0.000),
            CIColor(red: 0.500, green: 0.750, blue: 0.000),
            CIColor(red: 0.000, green: 0.250, blue: 0.500),
            CIColor(red: 0.875, green: 0.875, blue: 0.750)
        ]
        
        static let inputSize: CGSize = CGSize(width: 1024, height: 1024)
    }
    
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
                              color: CIColor(red: 0.502, green: 0.251, blue: 0.502)),
            SegmentationClass(name: "Sidewalk", grayscaleValue: 8.0 / 255.0, labelValue: 8,
                              color: CIColor(red: 0.957, green: 0.137, blue: 0.910)),
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
    
    struct CityScapesConstants2 { // CityScapes
        static let classes: [String] = [
//            "Unlabeled", "Ego vehicle", "Rectification border", "Out of roi", "Static",
            "Dynamic", "Ground",
            "Road", "Sidewalk", "Parking", "Rail track", "Building", "Wall", "Fence", "Guard rail", "Bridge",
            "Tunnel", "Pole", "Polegroup", "Traffic light", "Traffic sign", "Vegetation", "Terrain", "Sky", "Person",
            "Rider", "Car", "Truck", "Bus", "Caravan", "Trailer", "Train", "Motorcycle", "Bicycle"
            //, "License plate"
        ]
        
        static let grayValues: [Float] = [
//            0, 1, 2, 3, 4,
            5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
            25, 26, 27, 28, 29, 30, 31, 32, 33
//            , -1
        ].map{Float($0)/255.0}
        
        // Note: Do not use black (0, 0, 0) color, as significant portion of object detection relies on
        //  treating black color as no object in a segmentation mask
        static let grayscaleToClassMap: [UInt8: String] = [
//            0: "Unlabeled",
//            1: "Ego vehicle",
//            2: "Rectification border",
//            3: "Out of roi",
//            4: "Static",
            5: "Dynamic",
            6: "Ground",
            7: "Road",
            8: "Sidewalk",
            9: "Parking",
            10: "Rail track",
            11: "Building",
            12: "Wall",
            13: "Fence",
            14: "Guard rail",
            15: "Bridge",
            16: "Tunnel",
            17: "Pole",
            18: "Polegroup",
            19: "Traffic light",
            20: "Traffic sign",
            21: "Vegetation",
            22: "Terrain",
            23: "Sky",
            24: "Person",
            25: "Rider",
            26: "Car",
            27: "Truck",
            28: "Bus",
            29: "Caravan",
            30: "Trailer",
            31: "Train",
            32: "Motorcycle",
            33: "Bicycle",
//            -1: "License plate"
        ]
        
        static let colors: [CIColor] = [
//            CIColor(red: 0.0, green: 0.0, blue: 0.0),
//            CIColor(red: 0.0, green: 0.0, blue: 0.0),
//            CIColor(red: 0.0, green: 0.0, blue: 0.0),
//            CIColor(red: 0.0, green: 0.0, blue: 0.0),
//            CIColor(red: 0.0, green: 0.0, blue: 0.0),
            CIColor(red: 0.43529411764705883, green: 0.2901960784313726, blue: 0.0),
            CIColor(red: 0.3176470588235294, green: 0.0, blue: 0.3176470588235294),
            CIColor(red: 0.5019607843137255, green: 0.25098039215686274, blue: 0.5019607843137255),
            CIColor(red: 0.9568627450980393, green: 0.13725490196078433, blue: 0.9098039215686274),
            CIColor(red: 0.9803921568627451, green: 0.6666666666666666, blue: 0.6274509803921569),
            CIColor(red: 0.9019607843137255, green: 0.5882352941176471, blue: 0.5490196078431373),
            CIColor(red: 0.27450980392156865, green: 0.27450980392156865, blue: 0.27450980392156865),
            CIColor(red: 0.4, green: 0.4, blue: 0.611764705882353),
            CIColor(red: 0.7450980392156863, green: 0.6, blue: 0.6),
            CIColor(red: 0.7058823529411765, green: 0.6470588235294118, blue: 0.7058823529411765),
            CIColor(red: 0.5882352941176471, green: 0.39215686274509803, blue: 0.39215686274509803),
            CIColor(red: 0.5882352941176471, green: 0.47058823529411764, blue: 0.35294117647058826),
            CIColor(red: 0.6, green: 0.6, blue: 0.6),
            CIColor(red: 0.6, green: 0.6, blue: 0.6),
            CIColor(red: 0.9803921568627451, green: 0.6666666666666666, blue: 0.11764705882352941),
            CIColor(red: 0.8627450980392157, green: 0.8627450980392157, blue: 0.0),
            CIColor(red: 0.4196078431372549, green: 0.5568627450980392, blue: 0.13725490196078433),
            CIColor(red: 0.596078431372549, green: 0.984313725490196, blue: 0.596078431372549),
            CIColor(red: 0.27450980392156865, green: 0.5098039215686274, blue: 0.7058823529411765),
            CIColor(red: 0.8627450980392157, green: 0.0784313725490196, blue: 0.23529411764705882),
            CIColor(red: 1.0, green: 0.0, blue: 0.0),
            CIColor(red: 0.0, green: 0.0, blue: 0.5568627450980392),
            CIColor(red: 0.0, green: 0.0, blue: 0.27450980392156865),
            CIColor(red: 0.0, green: 0.23529411764705882, blue: 0.39215686274509803),
            CIColor(red: 0.0, green: 0.0, blue: 0.35294117647058826),
            CIColor(red: 0.0, green: 0.0, blue: 0.43137254901960786),
            CIColor(red: 0.0, green: 0.3137254901960784, blue: 0.39215686274509803),
            CIColor(red: 0.0, green: 0.0, blue: 0.9019607843137255),
            CIColor(red: 0.4666666666666667, green: 0.043137254901960784, blue: 0.12549019607843137),
            CIColor(red: 0.0, green: 0.0, blue: 0.5568627450980392)
        ]
        
        static let inputSize: CGSize = CGSize(width: 1024, height: 512)
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
