//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/24/24.
//

import SwiftUI

// Constants related to the supported classes
struct Constants {
    // Supported Classes
    struct VOCConstants {
        static let classes = ["Background", "Aeroplane", "Bicycle", "Bird", "Boat", "Bottle", "Bus", "Car", "Cat", "Chair", "Cow", "Diningtable", "Dog", "Horse", "Motorbike", "Person", "Pottedplant", "Sheep", "Sofa", "Train", "TV"]
        
        static let grayValues: [Float] = [12, 36, 48, 84, 96, 108, 132, 144, 180, 216, 228, 240].map{Float($0)/255.0}
        
        static let grayscaleToClassMap: [UInt8: String] = [
            12: "Background",
            36: "Aeroplane",
            48: "Bicycle",
            84: "Bird",
            96: "Boat",
            108: "Bottle",
            132: "Bus",
            144: "Car",
            180: "Cat",
            216: "Chair",
            228: "Cow",
            240: "Diningtable"
        ]
        
        static let colors: [CIColor] = [
            CIColor(red: 1.0, green: 0.0, blue: 0.0),      // Red
            CIColor(red: 0.0, green: 1.0, blue: 0.0),      // Green
            CIColor(red: 0.0, green: 0.0, blue: 1.0),      // Blue
            CIColor(red: 0.5, green: 0.0, blue: 0.5),      // Purple
            CIColor(red: 1.0, green: 0.65, blue: 0.0),     // Orange
            CIColor(red: 1.0, green: 1.0, blue: 0.0),      // Yellow
            CIColor(red: 0.65, green: 0.16, blue: 0.16),   // Brown
            CIColor(red: 0.0, green: 1.0, blue: 1.0),      // Cyan
            CIColor(red: 0.0, green: 0.5, blue: 0.5),      // Teal
            CIColor(red: 1.0, green: 0.75, blue: 0.8),     // Pink
            CIColor(red: 1.0, green: 1.0, blue: 1.0),      // White
            CIColor(red: 1.0, green: 0.0, blue: 1.0),      // Magenta
            CIColor(red: 0.5, green: 0.5, blue: 0.5)       // Gray
        ]
    }
    
    struct ClassConstants { // CityScapes
        static let classes: [String] = ["Unlabeled", "Ego vehicle", "Rectification border", "Out of roi", "Static", "Dynamic", "Ground",
                                        "Road", "Sidewalk", "Parking", "Rail track", "Building", "Wall", "Fence", "Guard rail", "Bridge",
                                        "Tunnel", "Pole", "Polegroup", "Traffic light", "Traffic sign", "Vegetation", "Terrain", "Sky", "Person",
                                        "Rider", "Car", "Truck", "Bus", "Caravan", "Trailer", "Train", "Motorcycle", "Bicycle"
                                        //, "License plate"
        ]
        
        static let grayValues: [Float] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 
                                          25, 26, 27, 28, 29, 30, 31, 32, 33
//                                          , -1
        ].map{Float($0)/255.0}
        
        static let grayscaleToClassMap: [UInt8: String] = [
            0: "Unlabeled",
            1: "Ego vehicle",
            2: "Rectification border",
            3: "Out of roi",
            4: "Static",
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
            CIColor(red: 0.0, green: 0.0, blue: 0.0),
            CIColor(red: 0.0, green: 0.0, blue: 0.0),
            CIColor(red: 0.0, green: 0.0, blue: 0.0),
            CIColor(red: 0.0, green: 0.0, blue: 0.0),
            CIColor(red: 0.0, green: 0.0, blue: 0.0),
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
    }
}
