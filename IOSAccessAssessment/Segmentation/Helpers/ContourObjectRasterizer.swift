//
//  ContourObjectRasterizer.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/18/25.
//

import CoreImage
import UIKit

func rasterizeContourObjects(objects: [DetectedObject], size: CGSize) -> CIImage? {
    func colorForClass(_ classLabel: UInt8, labelToColorMap: [UInt8: CIColor]) -> UIColor {
        let color = labelToColorMap[classLabel] ?? CIColor(red: 0, green: 0, blue: 0)
        return UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1.0)
    }
    
    UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
    guard let context = UIGraphicsGetCurrentContext() else { return nil }
    
    let labelToColorMap = Constants.ClassConstants.labelToColorMap
    for object in objects {
        let color = colorForClass(object.classLabel, labelToColorMap: labelToColorMap)
//        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(4.0)
        
        let path = UIBezierPath()
        guard let firstPoint = object.normalizedPoints.first else { continue }
        
        let firstPixelPoint = CGPoint(x: CGFloat(firstPoint.x) * size.width, y: (1 - CGFloat(firstPoint.y)) * size.height)
        path.move(to: firstPixelPoint)
        
        for point in object.normalizedPoints.dropFirst() {
            let pixelPoint = CGPoint(x: CGFloat(point.x) * size.width, y: (1 - CGFloat(point.y)) * size.height)
            path.addLine(to: pixelPoint)
        }
        path.close()
        
        context.addPath(path.cgPath)
//        context.fillPath()
        context.strokePath()
    }
    let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    UIGraphicsEndImageContext()
    
    if let cgImage = cgImage {
        return CIImage(cgImage: cgImage)
    }
    return nil
}
