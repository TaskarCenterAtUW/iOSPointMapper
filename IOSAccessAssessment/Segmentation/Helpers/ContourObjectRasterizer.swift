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

// Temporary config struct
struct RasterizeConfig {
    let draw: Bool
    let color: UIColor
    let width: CGFloat
    
    init(draw: Bool = true, color: UIColor = .white, width: CGFloat = 2.0) {
        self.draw = draw
        self.color = color
        self.width = width
    }
}

struct ContourObjectRasterizer {
    static func rasterizeContourObjects(
        objects: [DetectedObject], size: CGSize,
        polygonConfig: RasterizeConfig = RasterizeConfig(color: .green, width: 2.0),
        boundsConfig: RasterizeConfig = RasterizeConfig(color: .red, width: 2.0),
        wayBoundsConfig: RasterizeConfig = RasterizeConfig(color: .blue, width: 2.0),
        centroidConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0)
    ) -> CIImage? {
        func colorForClass(_ classLabel: UInt8, labelToColorMap: [UInt8: CIColor]) -> UIColor {
            let color = labelToColorMap[classLabel] ?? CIColor(red: 0, green: 0, blue: 0)
            return UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1.0)
        }
        
        func createPath(points: [SIMD2<Float>], size: CGSize) -> UIBezierPath {
            let path = UIBezierPath()
            guard let firstPoint = points.first else { return path }
            
            let firstPixelPoint = CGPoint(x: CGFloat(firstPoint.x) * size.width, y: (1 - CGFloat(firstPoint.y)) * size.height)
            path.move(to: firstPixelPoint)
            
            for point in points.dropFirst() {
                let pixelPoint = CGPoint(x: CGFloat(point.x) * size.width, y: (1 - CGFloat(point.y)) * size.height)
                path.addLine(to: pixelPoint)
            }
            path.close()
            return path
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let labelToColorMap = Constants.ClassConstants.labelToColorMap
        for object in objects {
            /// First, draw the contour
            if polygonConfig.draw {
                let path = createPath(points: object.normalizedPoints, size: size)
                
                context.setStrokeColor(polygonConfig.color.cgColor)
                context.setLineWidth(polygonConfig.width)
                context.addPath(path.cgPath)
        //        context.fillPath()
                context.strokePath()
            }
            
            /// Then, draw the way bound if exists
            if wayBoundsConfig.draw && object.wayBounds != nil {
                let wayBounds = object.wayBounds!
                let wayPath = createPath(points: wayBounds, size: size)
                context.setStrokeColor(wayBoundsConfig.color.cgColor)
                context.setLineWidth(wayBoundsConfig.width)
                context.addPath(wayPath.cgPath)
                context.strokePath()
            }
            
            if boundsConfig.draw {
                let boundingBox = object.boundingBox
                let boundingBoxRect = CGRect(x: CGFloat(boundingBox.origin.x) * size.width,
                                                y: (1 - CGFloat(boundingBox.origin.y + boundingBox.size.height)) * size.height,
                                                width: CGFloat(boundingBox.size.width) * size.width,
                                                height: CGFloat(boundingBox.size.height) * size.height)
                
                context.setStrokeColor(boundsConfig.color.cgColor)
                context.setLineWidth(boundsConfig.width)
                context.addRect(boundingBoxRect)
                context.strokePath()
            }
            
            /// Lastly, circle the center point
            if centroidConfig.draw {
                let centroid = object.centroid
                let centroidPoint = CGPoint(x: CGFloat(centroid.x) * size.width, y: (1 - CGFloat(centroid.y)) * size.height)
                context.setFillColor(centroidConfig.color.cgColor)
                context.addEllipse(in: CGRect(x: centroidPoint.x - centroidConfig.width,
                                              y: centroidPoint.y - centroidConfig.width,
                                              width: 2 * centroidConfig.width,
                                              height: 2 * centroidConfig.width))
                context.fillPath()
            }
        }
        let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
        UIGraphicsEndImageContext()
        
        if let cgImage = cgImage {
            return CIImage(cgImage: cgImage)
        }
        return nil
    }
}
