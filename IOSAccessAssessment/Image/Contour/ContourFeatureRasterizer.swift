//
//  ContourFeatureRasterizer.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/18/25.
//

import CoreImage
import UIKit

/**
 A temporary struct to perform rasterization of detected objects.
 TODO: This should be replaced by a lower-level rasterization function that uses Metal or Core Graphics directly.
 */
struct ContourFeatureRasterizer {
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
    
    static func rasterizeFeatures(
        detectedFeatures: [any DetectedFeatureProtocol], size: CGSize,
        polygonConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        boundsConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        centroidConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0)
    ) -> CGImage? {
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        for feature in detectedFeatures {
            let featureContourDetails = feature.contourDetails
            let featureColor: UIColor = UIColor(ciColor: feature.accessibilityFeatureClass.color)
            /// First, draw the contour
            if polygonConfig.draw {
                let path = createPath(points: featureContourDetails.normalizedPoints, size: size)
                let polygonColor = polygonConfig.color ?? featureColor
                context.setStrokeColor(polygonColor.cgColor)
                context.setLineWidth(polygonConfig.width)
                context.addPath(path.cgPath)
        //        context.fillPath()
                context.strokePath()
            }
            
            if boundsConfig.draw {
                let boundingBox = featureContourDetails.boundingBox
                let boundingBoxRect = CGRect(x: CGFloat(boundingBox.origin.x) * size.width,
                                                y: (1 - CGFloat(boundingBox.origin.y + boundingBox.size.height)) * size.height,
                                                width: CGFloat(boundingBox.size.width) * size.width,
                                                height: CGFloat(boundingBox.size.height) * size.height)
                let boundsColor = boundsConfig.color ?? featureColor
                context.setStrokeColor(boundsColor.cgColor)
                context.setLineWidth(boundsConfig.width)
                context.addRect(boundingBoxRect)
                context.strokePath()
            }
            
            /// Lastly, circle the center point
            if centroidConfig.draw {
                let centroid = featureContourDetails.centroid
                let centroidPoint = CGPoint(x: CGFloat(centroid.x) * size.width, y: (1 - CGFloat(centroid.y)) * size.height)
                let centroidColor = centroidConfig.color ?? featureColor
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
        
        return cgImage
    }
    
    static func updateRasterizedFeatures(
        baseImage: CGImage,
        detectedFeature: [any DetectedFeatureProtocol], size: CGSize,
        polygonConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        boundsConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0),
        centroidConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0)
    ) -> CGImage? {
        let baseUIImage = UIImage(cgImage: baseImage)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return baseImage }
        
        baseUIImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        for feature in detectedFeature {
            let featureContourDetails = feature.contourDetails
            let featureColor: UIColor = UIColor(ciColor: feature.accessibilityFeatureClass.color)
            /// First, draw the contour
            if polygonConfig.draw {
                let path = createPath(points: featureContourDetails.normalizedPoints, size: size)
                let polygonColor = polygonConfig.color ?? featureColor
                context.setStrokeColor(polygonColor.cgColor)
                context.setLineWidth(polygonConfig.width)
                context.addPath(path.cgPath)
        //        context.fillPath()
                context.strokePath()
            }
            
            if boundsConfig.draw {
                let boundingBox = featureContourDetails.boundingBox
                let boundingBoxRect = CGRect(x: CGFloat(boundingBox.origin.x) * size.width,
                                                y: (1 - CGFloat(boundingBox.origin.y + boundingBox.size.height)) * size.height,
                                                width: CGFloat(boundingBox.size.width) * size.width,
                                                height: CGFloat(boundingBox.size.height) * size.height)
                let boundsColor = boundsConfig.color ?? featureColor
                context.setStrokeColor(boundsColor.cgColor)
                context.setLineWidth(boundsConfig.width)
                context.addRect(boundingBoxRect)
                context.strokePath()
            }
            
            /// Lastly, circle the center point
            if centroidConfig.draw {
                let centroid = featureContourDetails.centroid
                let centroidPoint = CGPoint(x: CGFloat(centroid.x) * size.width, y: (1 - CGFloat(centroid.y)) * size.height)
                let centroidColor = centroidConfig.color ?? featureColor
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
        
        return cgImage
    }
    
    /**
    Rasterizes filled contours for the given detected features. This is used for generating segmentation masks.
     */
    static func rasterizeFeaturesFill(
        detectedFeatures: [any DetectedFeatureProtocol], size: CGSize,
        polygonConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 1.0)
    ) -> CGImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        for feature in detectedFeatures {
            let featureContourDetails = feature.contourDetails
            let featureColor: UIColor = UIColor(ciColor: feature.accessibilityFeatureClass.color)
            /// First, draw the contour
            if polygonConfig.draw {
                let path = createPath(points: featureContourDetails.normalizedPoints, size: size)
                let polygonColor = polygonConfig.color ?? featureColor
                context.setFillColor(polygonColor.cgColor)
                context.addPath(path.cgPath)
                context.fillPath()
            }
        }
        let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
        UIGraphicsEndImageContext()
        
        return cgImage
    }
}
