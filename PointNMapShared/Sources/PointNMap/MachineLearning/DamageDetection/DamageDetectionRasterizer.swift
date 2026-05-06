//
//  DamageDetectionRasterizer.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/4/26.
//

import CoreImage
import UIKit

public struct DamageDetectionRasterizer {
    public static func rasterizeDamageDetection(
        damageDetectionResults: [DamageDetectionResult],
        size: CGSize,
        boundsConfig: RasterizeConfig = RasterizeConfig(color: .red, width: 8.0)
    ) -> CGImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        for result in damageDetectionResults {
            let boundsColor = boundsConfig.color ?? UIColor.white
//            let boundingBoxRect = CGRect(x: CGFloat(boundingBox.origin.x) * size.width,
//                                         y: (1 - CGFloat(boundingBox.origin.y + boundingBox.size.height)) * size.height,
//                                         width: CGFloat(boundingBox.size.width) * size.width,
//                                         height: CGFloat(boundingBox.size.height) * size.height)
            let boundingBoxRect = result.getPixelCGRect(for: size)
            context.setStrokeColor(boundsColor.cgColor)
            context.setLineWidth(boundsConfig.width)
            context.addRect(boundingBoxRect)
            context.strokePath()
        }
        
        let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
        UIGraphicsEndImageContext()
        
        return cgImage
    }
}
