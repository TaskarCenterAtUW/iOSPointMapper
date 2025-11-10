//
//  FrameRasterizer.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 10/27/25.
//

import CoreImage
import UIKit

/**
 A custom Image that displays a bounding box around the region of processing
 */
struct FrameRasterizer {
    /**
     This function creates a CGImage with a bounding box drawn on it.
     */
    static func create(imageSize: CGSize, frameSize: CGSize) -> CGImage? {
        UIGraphicsBeginImageContextWithOptions(imageSize, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let frameRect = CenterCropTransformUtils.centerCropAspectFitBoundingRect(imageSize: imageSize, to: frameSize)
        
        context.setStrokeColor(UIColor.white.cgColor)
        context.setShadow(offset: .zero, blur: 5.0, color: UIColor.black.cgColor)
        context.setLineWidth(10.0)
        
        context.addRect(frameRect)
        context.strokePath()
        
        let boxedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return boxedImage?.cgImage
    }
}
