//
//  DepthMapProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/29/25.
//

import CoreImage
import CoreVideo

enum DepthMapProcessorError: Error, LocalizedError {
    case unableToAccessDepthData
    case invalidDepth
    
    var errorDescription: String? {
        switch self {
        case .unableToAccessDepthData:
            return "Unable to access depth data from the depth map."
        case .invalidDepth:
            return "The depth value retrieved is invalid."
        }
    }
}

struct DepthMapProcessor {
    let depthImage: CIImage
    
    private let context: CIContext
    
    private let depthWidth: Int
    private let depthHeight: Int
    private let depthBuffer: CVPixelBuffer
    
    init(depthImage: CIImage) throws {
        self.depthImage = depthImage
        self.context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        self.depthWidth = Int(depthImage.extent.width)
        self.depthHeight = Int(depthImage.extent.height)
        self.depthBuffer = try depthImage.toPixelBuffer(
            context: context,
            pixelFormatType: kCVPixelFormatType_DepthFloat32,
            colorSpace: nil
        )
        print("DepthMapProcessor initialized with depth image of size: \(depthWidth)x\(depthHeight)")
    }
    
    private func getDepthAtPoint(point: CGPoint) throws -> Float {
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
    
    private func getDepthsAtPoints(points: [CGPoint]) throws -> [Float] {
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
    
    /**
        Retrieves the depth value at the centroid of the given accessibility feature.
     
        - Parameters:
            - accessibilityFeature: The AccessibilityFeature object containing the detected feature.
     
        - Returns: The depth value at the centroid of the feature.
     
        - Throws: DepthMapProcessorError.unableToAccessDepthData if depth data cannot be accessed.
                    DepthMapProcessorError.invalidDepth if the retrieved depth value is invalid.
     
        - Note: The centroid coordinates are normalized (0 to 1) and need to be converted to pixel coordinates.
     */
    func getFeatureDepthAtCentroid(detectedFeature: any DetectedFeatureProtocol) throws -> Float {
        let featureContourDetails = detectedFeature.contourDetails
        let featureCentroid = featureContourDetails.centroid
        
        let featureCentroidPoint: CGPoint = CGPoint(
            x: featureCentroid.x * CGFloat(depthWidth),
            y: (1 - featureCentroid.y) * CGFloat(depthHeight)
        )
        return try getDepthAtPoint(point: featureCentroidPoint)
    }
    
    /**
        Retrieves the average depth value within a specified radius around the centroid of the given accessibility feature.
     
        - Parameters:
            - accessibilityFeature: The AccessibilityFeature object containing the detected feature.
            - radius: The radius (in pixels) around the centroid to consider for averaging depth values. Default is 5 pixels.
     
        - Returns: The average depth value within the specified radius around the feature's centroid.
     
        - Throws: DepthMapProcessorError.unableToAccessDepthData if depth data cannot be accessed.
                    DepthMapProcessorError.invalidDepth if no valid depth values are found within the radius.
     
        - Note: The centroid coordinates are normalized (0 to 1) and need to be converted to pixel coordinates.
     */
    func getFeatureDepthAtCentroidInRadius(detectedFeature: any DetectedFeatureProtocol, radius: CGFloat = 5) throws -> Float {
        let featureContourDetails = detectedFeature.contourDetails
        let featureCentroid = featureContourDetails.centroid
        
        var pointDeltas: [CGPoint] = []
        for xDelta in stride(from: -radius, through: radius, by: 1) {
            for yDelta in stride(from: -radius, through: radius, by: 1) {
                let distance = sqrt(xDelta * xDelta + yDelta * yDelta)
                if distance <= radius {
                    pointDeltas.append(CGPoint(x: xDelta, y: yDelta))
                }
            }
        }
        
        let featureCentroidRadiusPoints: [CGPoint] = pointDeltas.map { delta in
            CGPoint(
                x: featureCentroid.x * CGFloat(depthWidth) + delta.x,
                /// Symmetry in circle ensures that we do not worry about the sign of delta.y here
                y: (1 - featureCentroid.y) * CGFloat(depthHeight) + delta.y
            )
        }
        let depths = try getDepthsAtPoints(points: featureCentroidRadiusPoints)
        let validDepths = depths.filter { $0.isFinite && $0 > 0 }
        guard !validDepths.isEmpty else {
            throw DepthMapProcessorError.invalidDepth
        }
        let averageDepth = validDepths.reduce(0, +) / Float(validDepths.count)
        return averageDepth
    }
    
    func getFeatureDepthsAtBounds(detectedFeature: any DetectedFeatureProtocol) throws -> [Float] {
        let featureContourDetails = detectedFeature.contourDetails
        let normalizedPoints: [SIMD2<Float>] = featureContourDetails.normalizedPoints
        
        let featureBoundPoints: [CGPoint] = normalizedPoints.map { point in
            CGPoint(
                x: CGFloat(point.x * Float(depthWidth)),
                y: CGFloat((1 - point.y) * Float(depthHeight))
            )
        }
        let depths = try getDepthsAtPoints(points: featureBoundPoints)
        return depths
    }
    
    func getFeatureDepthsAtNormalizedPoints(_ points: [SIMD2<Float>]) throws -> [Float] {
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
