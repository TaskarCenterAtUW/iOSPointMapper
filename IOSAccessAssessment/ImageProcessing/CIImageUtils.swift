//
//  CIImageUtils.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/27/24.
//

import UIKit

extension CIImage {
    func croppedToCenter(size: CGSize) -> CIImage {
        let x = (extent.width - size.width) / 2
        let y = (extent.height - size.height) / 2
        let cropRect = CGRect(x: x, y: y, width: size.width, height: size.height)
        return cropped(to: cropRect)
    }
}

func computeCentroid(mask: CVPixelBuffer, depthMap: CVPixelBuffer, sidewalkLabel: UInt8 = 1) -> (Double, Double)? {
    // Ensure the dimensions of mask and depthMap are the same
    guard CVPixelBufferGetWidth(mask) == CVPixelBufferGetWidth(depthMap),
          CVPixelBufferGetHeight(mask) == CVPixelBufferGetHeight(depthMap) else {
        print("Mask and Depth Map dimensions do not match.")
        return nil
    }

    let width = CVPixelBufferGetWidth(mask)
    let height = CVPixelBufferGetHeight(mask)

    CVPixelBufferLockBaseAddress(mask, .readOnly)
    CVPixelBufferLockBaseAddress(depthMap, .readOnly)

    defer {
        CVPixelBufferUnlockBaseAddress(mask, .readOnly)
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
    }

    guard let maskBaseAddress = CVPixelBufferGetBaseAddress(mask),
          let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
        print("Failed to get base address of mask or depth map.")
        return nil
    }

    var xIndices = [Int]()
    var yIndices = [Int]()

    for y in 0..<height {
        for x in 0..<width {
            let maskPixelIndex = y * CVPixelBufferGetBytesPerRow(mask) + x
            let maskValue = maskBaseAddress.assumingMemoryBound(to: UInt8.self)[maskPixelIndex]
            if maskValue == sidewalkLabel {
                xIndices.append(x)
                yIndices.append(y)
            }
        }
    }

    if xIndices.isEmpty || yIndices.isEmpty {
        print("No sidewalk pixels found.")
        return nil
    }

    let xMedian = Double(xIndices.sorted()[xIndices.count / 2])
    let yMedian = Double(yIndices.sorted()[yIndices.count / 2])

    return (xMedian, yMedian)
}

func computeSidewalkWidth(mask: CVPixelBuffer, depthMap: CVPixelBuffer, centroid: (Double, Double)) -> Double? {
    let centroidX = Int(centroid.0)
    let centroidY = Int(centroid.1)

    guard CVPixelBufferGetWidth(mask) == CVPixelBufferGetWidth(depthMap),
          CVPixelBufferGetHeight(mask) == CVPixelBufferGetHeight(depthMap) else {
        print("Mask and Depth Map dimensions do not match.")
        return nil
    }

    let width = CVPixelBufferGetWidth(mask)
    CVPixelBufferLockBaseAddress(mask, .readOnly)
    CVPixelBufferLockBaseAddress(depthMap, .readOnly)

    defer {
        CVPixelBufferUnlockBaseAddress(mask, .readOnly)
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
    }

    guard let maskBaseAddress = CVPixelBufferGetBaseAddress(mask),
          let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
        print("Failed to get base address of mask or depth map.")
        return nil
    }

    let rowOffset = centroidY * CVPixelBufferGetBytesPerRow(mask)
    var sidewalkIndices = [Int]()

    for x in 0..<width {
        let maskValue = maskBaseAddress.assumingMemoryBound(to: UInt8.self)[rowOffset + x]
        if maskValue > 0 {
            sidewalkIndices.append(x)
        }
    }

    if sidewalkIndices.count < 2 {
        print("Cannot find sidewalk edges at the centroid location.")
        return nil
    }

    let leftPixel = sidewalkIndices.first!
    let rightPixel = sidewalkIndices.last!

    let sideDepth = depthBaseAddress.assumingMemoryBound(to: Double.self)[centroidY * width + centroidX]
    let leftDepth = depthBaseAddress.assumingMemoryBound(to: Double.self)[centroidY * width + leftPixel]
    let rightDepth = depthBaseAddress.assumingMemoryBound(to: Double.self)[centroidY * width + rightPixel]

    let leftEstimate = sqrt(pow(leftDepth, 2) - pow(sideDepth, 2))
    let rightEstimate = sqrt(pow(rightDepth, 2) - pow(sideDepth, 2))

    return (leftEstimate + rightEstimate) / 2
}
