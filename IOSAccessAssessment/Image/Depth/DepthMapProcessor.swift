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
    
    var errorDescription: String? {
        switch self {
        case .unableToAccessDepthData:
            return "Unable to access depth data from the depth map."
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
    }
    
    func getDepthAtCentroid(accessibilityFeature: AccessibilityFeature) throws -> Float {
        let featureContourDetails = accessibilityFeature.detectedAccessibilityFeature.contourDetails
        let featureCentroid = featureContourDetails.centroid
        
        CVPixelBufferLockBaseAddress(depthBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthBuffer, .readOnly) }
        
        guard let depthBaseAddress = CVPixelBufferGetBaseAddress(depthBuffer) else {
            throw DepthMapProcessorError.unableToAccessDepthData
        }
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthBuffer)
        let depthBuffer = depthBaseAddress.assumingMemoryBound(to: Float.self)
        
        /**
         TODO: Check if the y-axis needs to be flipped based on coordinate systems
         */
        let featureCentroidCoordinates: CGPoint = CGPoint(
            x: featureCentroid.x * CGFloat(depthWidth),
            y: (1 - featureCentroid.y) * CGFloat(depthHeight)
        )
        let featureDepthIndexRow = Int(featureCentroidCoordinates.y)
        let featureDepthIndexCol = Int(featureCentroidCoordinates.x)
        let featureDepthIndex = featureDepthIndexRow * (depthBytesPerRow / MemoryLayout<Float>.size) + featureDepthIndexCol
        let depthAtCentroid = depthBuffer[featureDepthIndex]
        return depthAtCentroid
    }
}
