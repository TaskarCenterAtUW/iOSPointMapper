//
//  ContourObjectRasterizer.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/18/25.
//

import CoreImage
import UIKit

/**
    Rasterizes detected contour objects into a CIImage.
    A helper function that is not used in the main app currently, but can be useful for debugging or visualization purposes.
 */
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
        
        /// First, draw the contour
        let path = UIBezierPath()
        guard let firstPoint = object.normalizedPoints.first else { continue }
        
        let firstPixelPoint = CGPoint(x: CGFloat(firstPoint.x) * size.width, y: (1 - CGFloat(firstPoint.y)) * size.height)
        path.move(to: firstPixelPoint)
        
        for point in object.normalizedPoints.dropFirst() {
            let pixelPoint = CGPoint(x: CGFloat(point.x) * size.width, y: (1 - CGFloat(point.y)) * size.height)
            path.addLine(to: pixelPoint)
        }
        path.close()
        
//        context.setFillColor(color.cgColor)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(4.0)
        context.addPath(path.cgPath)
//        context.fillPath()
        context.strokePath()
        
        /// Then, draw the bounding box
        let boundingBox = object.boundingBox
        let boundingBoxRect = CGRect(x: CGFloat(boundingBox.origin.x) * size.width,
                                        y: (1 - CGFloat(boundingBox.origin.y + boundingBox.size.height)) * size.height,
                                        width: CGFloat(boundingBox.size.width) * size.width,
                                        height: CGFloat(boundingBox.size.height) * size.height)
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2.0)
        context.addRect(boundingBoxRect)
        context.strokePath()
        
        /// Lastly, circle the center point
        let centroid = object.centroid
        let centroidPoint = CGPoint(x: CGFloat(centroid.x) * size.width, y: (1 - CGFloat(centroid.y)) * size.height)
        context.setFillColor(color.cgColor)
        context.addEllipse(in: CGRect(x: centroidPoint.x - 5, y: centroidPoint.y - 5, width: 10, height: 10))
        context.fillPath()
    }
    let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
    UIGraphicsEndImageContext()
    
    if let cgImage = cgImage {
        return CIImage(cgImage: cgImage)
    }
    return nil
}
