//
//  RasterizeConfig.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/18/25.
//
import UIKit

public struct RasterizeConfig {
    public let draw: Bool
    public let color: UIColor?
    public let width: CGFloat
    public let alpha: CGFloat
    
    public init(draw: Bool = true, color: UIColor?, width: CGFloat = 2.0, alpha: CGFloat = 1.0) {
        self.draw = draw
        self.color = color
        self.width = width
        self.alpha = alpha
    }
}
