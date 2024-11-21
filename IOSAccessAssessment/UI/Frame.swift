//
//  Frame.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/10/24.
//

import SwiftUI

struct VerticalFrame {
    // MARK: This is a temporary function that is used to assign CGRect to the frame of a layer
    // Later, we will be refactoring the app with a more AutoLayout reliable solution
    // Currently, goes with the assumption that we want to display frames only in a single column (hence only row is an argument)
    static func getColumnFrame(width: Double, height: Double, row: Int) -> CGRect {
        // Currently, the app only supports portrait mode
        // Hence, we can set the size of the square frame relative to screen width
        // with the screen height acting as a threshold to support other frames and buttons
        // FIXME: Make this logic more robust to screen orientation
        //  so that we can eventually use other orientations
        let aspectRatio = Constants.ClassConstants.inputSize.width / Constants.ClassConstants.inputSize.height
        
        let sideLength = min(width * 0.9 / aspectRatio, height * 0.40)
        let sideWidth = sideLength * aspectRatio
        let sideHeight = sideLength

        let xPosition = (width - sideWidth) / 2
        let yPosition = sideHeight * CGFloat(row)

        return CGRect(x: xPosition, y: yPosition, width: sideWidth, height: sideHeight)
    }
}
