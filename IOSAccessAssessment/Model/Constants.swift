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
    struct ClassConstants {
        static let classes = ["Background", "Aeroplane", "Bicycle", "Bird", "Boat", "Bottle", "Bus", "Car", "Cat", "Chair", "Cow", "Diningtable", "Dog", "Horse", "Motorbike", "Person", "Pottedplant", "Sheep", "Sofa", "Train", "TV"]
        
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
        
        static let grayValues: [Float] = [12, 36, 48, 84, 96, 108, 132, 144, 180, 216, 228, 240].map{Float($0)/255.0}
        
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
}
