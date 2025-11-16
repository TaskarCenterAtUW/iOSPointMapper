//
//  MeshRasterizer.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/16/25.
//

import CoreImage
import UIKit

struct MeshRasterizer {
    static func createPath(points: [SIMD2<Float>]) -> UIBezierPath {
        let path = UIBezierPath()
        guard let firstPoint = points.first else { return path }
        
        let firstPixelPoint = CGPoint(x: CGFloat(firstPoint.x), y: (1 - CGFloat(firstPoint.y)))
        path.move(to: firstPixelPoint)
        
        for point in points.dropFirst() {
            let pixelPoint = CGPoint(x: CGFloat(point.x), y: (1 - CGFloat(point.y)))
            path.addLine(to: pixelPoint)
        }
        path.close()
        return path
    }
    
    static func rasterizeMesh(
        meshTriangles: [(CGPoint, CGPoint, CGPoint)], size: CGSize,
        boundsConfig: RasterizeConfig = RasterizeConfig(color: .white, width: 2.0)
    ) -> CGImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        for triangle in meshTriangles {
            if boundsConfig.draw {
                let points = [triangle.0, triangle.1, triangle.2].map { SIMD2<Float>(Float($0.x), Float($0.y)) }
                let path = createPath(points: points)
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
