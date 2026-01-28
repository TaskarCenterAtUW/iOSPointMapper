//
//  PlaneRasterizer.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/27/26.
//

import CoreImage
import UIKit

struct PlaneRasterizer {
    /**
     The path points for ProjectedPlane are unnormalized.
     */
    static func createPath(points: [SIMD2<Float>], size: CGSize) -> UIBezierPath {
        let path = UIBezierPath()
        guard let firstPoint = points.first else { return path }
        
        let firstPixelPoint = CGPoint(x: CGFloat(firstPoint.x), y: (size.height - CGFloat(firstPoint.y)))
        path.move(to: firstPixelPoint)
        
        for point in points.dropFirst() {
            let pixelPoint = CGPoint(x: CGFloat(point.x), y: (size.height - CGFloat(point.y)))
            path.addLine(to: pixelPoint)
        }
        
        path.close()
        return path
    }
    
    static func rasterizePlane(
        projectedPlane: ProjectedPlane,
        size: CGSize,
        linesConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 4.0)
    ) -> CGImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        let vectorsToDraw = [projectedPlane.firstEigenVector, projectedPlane.secondEigenVector]
        let colors = [UIColor.red, UIColor.blue]
        for (index, vector) in vectorsToDraw.enumerated() {
            let path = createPath(points: [vector.0, vector.1], size: size)
            context.addPath(path.cgPath)
            context.setStrokeColor(colors[index].cgColor)
            context.setLineWidth(linesConfig.width)
            context.strokePath()
        }
        
        let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
        UIGraphicsEndImageContext()
        
        if let cgImage = cgImage {
            return cgImage
        }
        return nil
    }
}
