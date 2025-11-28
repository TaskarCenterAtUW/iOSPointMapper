//
//  MeshRasterizer.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/16/25.
//

import CoreImage
import UIKit

/**
    Functions to rasterize mesh triangles into an image.
 */
struct MeshRasterizer {
    static func createPath(points: [SIMD2<Float>], size: CGSize) -> UIBezierPath {
        let path = UIBezierPath()
        guard let firstPoint = points.first else { return path }
        
        let firstPixelPoint = CGPoint(x: CGFloat(firstPoint.x) * size.width, y: CGFloat(firstPoint.y) * size.height)
        path.move(to: firstPixelPoint)
        
        for point in points.dropFirst() {
            let pixelPoint = CGPoint(x: CGFloat(point.x) * size.width, y: CGFloat(point.y) * size.height)
            path.addLine(to: pixelPoint)
        }
        
        path.close()
        return path
    }
    
    /**
        This function rasterizes mesh triangles into a CGImage.
     
        - Parameters:
            - meshTriangles: An array of triangles, each defined by three CGPoint vertices. Normalized coordinates
            - size: The size of the output image.
            - boundsConfig: Configuration for drawing triangle bounds, including color and line width.
     */
    static func rasterizeMesh(
        polygonsNormalizedCoordinates: [(SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)], size: CGSize,
        boundsConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0)
    ) -> CGImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        for triangle in polygonsNormalizedCoordinates {
            if boundsConfig.draw {
                let points = [triangle.0, triangle.1, triangle.2]
                let path = createPath(points: points, size: size)
                let boundsColor = boundsConfig.color ?? .white
                context.setStrokeColor(boundsColor.cgColor)
                context.setLineWidth(boundsConfig.width)
                context.addPath(path.cgPath)
                context.strokePath()
            }
        }
        
        let cgImage = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
        UIGraphicsEndImageContext()
        
        if let cgImage = cgImage {
            return cgImage
        }
        return nil
    }
}
