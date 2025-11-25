//
//  RasterizeConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/18/25.
//
import UIKit

struct RasterizeConfig {
    let draw: Bool
    let color: UIColor?
    let width: CGFloat
    let alpha: CGFloat
    
    init(draw: Bool = true, color: UIColor?, width: CGFloat = 2.0, alpha: CGFloat = 1.0) {
        self.draw = draw
        self.color = color
        self.width = width
        self.alpha = alpha
    }
}
