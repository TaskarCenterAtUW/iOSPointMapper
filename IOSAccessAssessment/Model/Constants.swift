//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/24/24.
//

import SwiftUI

// Constants related to the supported classes
struct Constants {
    struct ClassConstants {
        static let classes = ["Road", "Sidewalk", "Building", "Wall", "Fence", "Pole", "Traffic light", "Traffic sign", "Vegetation", "Terrain", "Sky", "Person", "Rider", "Car", "Truck", "Bus", "Train", "Motorcycle", "Bicycle", "Unlabeled"]
        
        static let grayValues: [Float] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 255].map{Float($0) / 255.0}
        
        static let grayscaleToClassMap: [UInt8: String] = [
            0: "Road",
            1: "Sidewalk",
            2: "Building",
            3: "Wall",
            4: "Fence",
            5: "Pole",
            6: "Traffic light",
            7: "Traffic sign",
            8: "Vegetation",
            9: "Terrain",
            10: "Sky",
            11: "Person",
            12: "Rider",
            13: "Car",
            14: "Truck",
            15: "Bus",
            16: "Train",
            17: "Motorcycle",
            18: "Bicycle",
            255: "Unlabeled"

        ]
        
        static let colors: [CIColor] = [
            CIColor(red: 0.502, green: 0.251, blue: 0.502),     // road (train_id: 0)
            CIColor(red: 0.957, green: 0.137, blue: 0.910),     // sidewalk (train_id: 1)
            CIColor(red: 0.275, green: 0.275, blue: 0.275),     // building (train_id: 2)
            CIColor(red: 0.400, green: 0.400, blue: 0.612),     // wall (train_id: 3)
            CIColor(red: 0.745, green: 0.600, blue: 0.600),     // fence (train_id: 4)
            CIColor(red: 0.600, green: 0.600, blue: 0.600),     // pole (train_id: 5)
            CIColor(red: 0.980, green: 0.667, blue: 0.118),     // traffic light (train_id: 6)
            CIColor(red: 0.863, green: 0.863, blue: 0.0),       // traffic sign (train_id: 7)
            CIColor(red: 0.420, green: 0.557, blue: 0.137),     // vegetation (train_id: 8)
            CIColor(red: 0.596, green: 0.984, blue: 0.596),     // terrain (train_id: 9)
            CIColor(red: 0.275, green: 0.510, blue: 0.706),     // sky (train_id: 10)
            CIColor(red: 0.863, green: 0.078, blue: 0.235),     // person (train_id: 11)
            CIColor(red: 1.0, green: 0.0, blue: 0.0),           // rider (train_id: 12)
            CIColor(red: 0.0, green: 0.0, blue: 0.557),         // car (train_id: 13)
            CIColor(red: 0.0, green: 0.0, blue: 0.275),         // truck (train_id: 14)
            CIColor(red: 0.0, green: 0.235, blue: 0.392),       // bus (train_id: 15)
            CIColor(red: 0.0, green: 0.314, blue: 0.392),       // train (train_id: 16)
            CIColor(red: 0.0, green: 0.0, blue: 0.902),         // motorcycle (train_id: 17)
            CIColor(red: 0.467, green: 0.043, blue: 0.125),     // bicycle (train_id: 18)
            CIColor(red: 0.0, green: 0.0, blue: 0.0)            // unlabeled (train_id: 255)
        ]
    }
}
