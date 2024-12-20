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
//            CIColor(red: 0.00, green: 0.00, blue: 0.00),
            CIColor(red: 0.50, green: 0.00, blue: 0.50),
            CIColor(red: 0.00, green: 0.50, blue: 0.00),
            CIColor(red: 0.50, green: 0.50, blue: 0.50),
            CIColor(red: 0.00, green: 0.00, blue: 0.00),
            CIColor(red: 0.50, green: 0.00, blue: 0.50),
            CIColor(red: 0.00, green: 0.50, blue: 0.00),
            CIColor(red: 0.50, green: 0.50, blue: 0.50),
            CIColor(red: 0.25, green: 0.00, blue: 0.25),
            CIColor(red: 0.75, green: 0.00, blue: 0.75),
            CIColor(red: 0.25, green: 0.50, blue: 0.25),
            CIColor(red: 0.75, green: 0.50, blue: 0.75),
            CIColor(red: 0.25, green: 0.00, blue: 0.25),
            CIColor(red: 0.75, green: 0.00, blue: 0.75),
            CIColor(red: 0.25, green: 0.50, blue: 0.25),
            CIColor(red: 0.75, green: 0.50, blue: 0.75),
            CIColor(red: 0.00, green: 0.25, blue: 0.00),
            CIColor(red: 0.50, green: 0.25, blue: 0.50),
            CIColor(red: 0.00, green: 0.75, blue: 0.00),
            CIColor(red: 0.50, green: 0.75, blue: 0.50),
            CIColor(red: 0.00, green: 0.25, blue: 0.00)
        ]
        
        static let inputSize: CGSize = CGSize(width: 1024, height: 1024)
    }
    
    struct CityScapesConstants { // CityScapes
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
