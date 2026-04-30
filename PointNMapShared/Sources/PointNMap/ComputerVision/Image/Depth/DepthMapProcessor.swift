//
//  DepthMapProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/29/25.
//

import CoreImage
import CoreVideo

public enum DepthMapProcessorError: Error, LocalizedError {
    case unableToAccessDepthData
    case invalidDepth
    
    public var errorDescription: String? {
        switch self {
        case .unableToAccessDepthData:
            return "Unable to access depth data from the depth map."
        case .invalidDepth:
            return "The depth value retrieved is invalid."
        }
    }
}

public struct DepthMapProcessor {
    public let depthImage: CIImage
    
    public let context: CIContext
    
    public let depthWidth: Int
    public let depthHeight: Int
    public let depthBuffer: CVPixelBuffer
    
    public init(depthImage: CIImage) throws {
        self.depthImage = depthImage
        self.context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        self.depthWidth = Int(depthImage.extent.width)
        self.depthHeight = Int(depthImage.extent.height)
        self.depthBuffer = try depthImage.toPixelBuffer(
            context: context,
            pixelFormatType: kCVPixelFormatType_DepthFloat32,
            colorSpace: nil
        )
    }
    
    public func getDepthAtPoint(point: CGPoint) throws -> Float {
        CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly) }
        
        guard let depthBaseAddress = CVPixelBufferGetBaseAddress(depthBuffer) else {
            throw DepthMapProcessorError.unableToAccessDepthData
        }
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
        let depthBuffer = depthBaseAddress.assumingMemoryBound(to: Float.self)
        
        let depthIndexRow = Int(point.y)
        let depthIndexCol = Int(point.x)
        let depthIndex = depthIndexRow * (depthBytesPerRow / MemoryLayout<Float>.size) + depthIndexCol
        let depthAtPoint = depthBuffer[depthIndex]
        return depthAtPoint
    }
    
    public func getDepthsAtPoints(points: [CGPoint]) throws -> [Float] {
        CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly) }
        
        guard let depthBaseAddress = CVPixelBufferGetBaseAddress(depthBuffer) else {
            throw DepthMapProcessorError.unableToAccessDepthData
        }
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
        let depthBuffer = depthBaseAddress.assumingMemoryBound(to: Float.self)
        
        var depths: [Float] = points.map { _ in 0.0 }
        for (index, point) in points.enumerated() {
            let depthIndexRow = Int(point.y)
            let depthIndexCol = Int(point.x)
            let depthIndex = depthIndexRow * (depthBytesPerRow / MemoryLayout<Float>.size) + depthIndexCol
            depths[index] = depthBuffer[depthIndex]
        }
        return depths
    }
    
    public func getFeatureDepthsAtNormalizedPoints(_ points: [SIMD2<Float>]) throws -> [Float] {
        let featurePoints: [CGPoint] = points.map { point in
            CGPoint(
                x: CGFloat(point.x * Float(depthWidth)),
                y: CGFloat((1 - point.y) * Float(depthHeight))
            )
        }
        let depths = try getDepthsAtPoints(points: featurePoints)
        return depths
    }
}
