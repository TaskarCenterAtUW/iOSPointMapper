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

/**
 A temporary struct to perform rasterization of detected objects.
 TODO: This should be replaced by a lower-level rasterization function that uses Metal or Core Graphics directly.
 */
struct ContourObjectRasterizer {
    static func colorForClass(_ classLabel: UInt8, labelToColorMap: [UInt8: CIColor]) -> UIColor {
        let color = labelToColorMap[classLabel] ?? CIColor(red: 0, green: 0, blue: 0)
        return UIColor(red: color.red, green: color.green, blue: color.blue, alpha: 1.0)
    }
    
    static func createPath(points: [SIMD2<Float>], size: CGSize) -> UIBezierPath {
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
    
    static func rasterizeContourObjects(
        objects: [DetectedObject], size: CGSize,
        polygonConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        boundsConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        wayBoundsConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        centroidConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0)
    ) -> CGImage? {
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let labelToColorMap = Constants.SelectedSegmentationConfig.labelToColorMap
        for object in objects {
            /// First, draw the contour
            if polygonConfig.draw {
                let path = createPath(points: object.normalizedPoints, size: size)
                let polygonColor = polygonConfig.color ?? colorForClass(object.classLabel, labelToColorMap: labelToColorMap)
                context.setStrokeColor(polygonColor.cgColor)
                context.setLineWidth(polygonConfig.width)
                context.addPath(path.cgPath)
        //        context.fillPath()
                context.strokePath()
            }
            
            /// Then, draw the way bound if exists
            if wayBoundsConfig.draw && object.wayBounds != nil {
                let wayBounds = object.wayBounds!
                let wayPath = createPath(points: wayBounds, size: size)
                let wayBoundsColor = wayBoundsConfig.color ?? colorForClass(object.classLabel, labelToColorMap: labelToColorMap)
                context.setStrokeColor(wayBoundsColor.cgColor)
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
                let boundsColor = boundsConfig.color ?? colorForClass(object.classLabel, labelToColorMap: labelToColorMap)
                context.setStrokeColor(boundsColor.cgColor)
                context.setLineWidth(boundsConfig.width)
                context.addRect(boundingBoxRect)
                context.strokePath()
            }
            
            /// Lastly, circle the center point
            if centroidConfig.draw {
                let centroid = object.centroid
                let centroidPoint = CGPoint(x: CGFloat(centroid.x) * size.width, y: (1 - CGFloat(centroid.y)) * size.height)
                let centroidColor = centroidConfig.color ?? colorForClass(object.classLabel, labelToColorMap: labelToColorMap)
                context.setFillColor(centroidColor.cgColor)
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
//            return CIImage(cgImage: cgImage)
            return cgImage
        }
        return nil
    }
    
    static func updateRasterizedImage(
        baseImage: CGImage,
        objects: [DetectedObject], size: CGSize,
        polygonConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        boundsConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        wayBoundsConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        centroidConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0)
    ) -> CGImage {
        let baseUIImage = UIImage(cgImage: baseImage)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return baseImage }
        
        baseUIImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        let labelToColorMap = Constants.SelectedSegmentationConfig.labelToColorMap
        for object in objects {
            /// First, draw the contour
            if polygonConfig.draw {
                let path = createPath(points: object.normalizedPoints, size: size)
                let polygonColor = polygonConfig.color ?? colorForClass(object.classLabel, labelToColorMap: labelToColorMap)
                context.setStrokeColor(polygonColor.cgColor)
                context.setLineWidth(polygonConfig.width)
                context.addPath(path.cgPath)
        //        context.fillPath()
                context.strokePath()
            }
            
            /// Then, draw the way bound if exists
            if wayBoundsConfig.draw && object.wayBounds != nil {
                let wayBounds = object.wayBounds!
                let wayPath = createPath(points: wayBounds, size: size)
                let wayBoundsColor = wayBoundsConfig.color ?? colorForClass(object.classLabel, labelToColorMap: labelToColorMap)
                context.setStrokeColor(wayBoundsColor.cgColor)
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
                let boundsColor = boundsConfig.color ?? colorForClass(object.classLabel, labelToColorMap: labelToColorMap)
                context.setStrokeColor(boundsColor.cgColor)
                context.setLineWidth(boundsConfig.width)
                context.addRect(boundingBoxRect)
                context.strokePath()
            }
            
            /// Lastly, circle the center point
            if centroidConfig.draw {
                let centroid = object.centroid
                let centroidPoint = CGPoint(x: CGFloat(centroid.x) * size.width, y: (1 - CGFloat(centroid.y)) * size.height)
                let centroidColor = centroidConfig.color ?? colorForClass(object.classLabel, labelToColorMap: labelToColorMap)
                context.setFillColor(centroidColor.cgColor)
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
            return cgImage
        }
        return baseImage
    }
}
