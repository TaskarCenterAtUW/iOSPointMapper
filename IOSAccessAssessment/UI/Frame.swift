//
//  Frame.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/24.
//
import SwiftUI

struct VerticalFrame {
    // This is a temporary function that is used to assign CGRect to the frame of a layer
    // Currently, goes with the assumption that we want to display frames only in a single column (hence only row is an argument)
    static func getColumnFrame(row: Int) -> CGRect {
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        
        // Currently, the app only supports portrait mode
        // Hence, we can set the size of the square frame relative to screen width
        // with the screen height acting as a threshold to support other frames and buttons
        // FIXME: Make this logic more robust to screen orientation
        //  so that we can eventually use other orientations
        let sideLength = min(screenWidth * 0.45, screenHeight * 0.40)
        let sideWidth = sideLength * 2
        let sideHeight = sideLength
        
        let xPosition = (screenWidth - sideWidth) / 2
        let yPosition = sideHeight * CGFloat(row)
        
        return CGRect(x: xPosition, y: yPosition, width: sideWidth, height: sideHeight)
    }
}
