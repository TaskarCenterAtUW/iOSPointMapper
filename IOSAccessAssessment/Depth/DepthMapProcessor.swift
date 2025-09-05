//
//  DepthMap.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/21/25.
//
import CoreImage
import CoreVideo

struct DepthMapProcessor {
    var depthImage: CIImage
    
    private let ciContext = CIContext(options: nil)
    
    private var depthMap: CVPixelBuffer? = nil
    private var depthMapWidth: Int = 0
    private var depthMapHeight: Int = 0
    
    init(depthImage: CIImage) {
        self.depthImage = depthImage
        let width = Int(depthImage.extent.width)
        let height = Int(depthImage.extent.height)
        self.depthMap = CVPixelBufferUtils.createPixelBuffer(width: width, height: height)
        ciContext.render(depthImage, to: self.depthMap!)
        self.depthMapWidth = width
        self.depthMapHeight = height
    }
    
    // FIXME: Use something like trimmed mean to eliminate outliers, instead of the normal mean
    /**
        This function calculates the depth value of the object at the centroid of the segmented image.
     
        segmentationLabelImage: The segmentation label image (pixel format: kCVPixelFormatType_OneComponent8)

        depthImage: The depth image (pixel format: kCVPixelFormatType_DepthFloat32). Not used in this function.
     */
    func getDepth(segmentationLabelImage: CIImage, depthImage: CIImage, classLabel: UInt8) -> Float {
        guard let depthMap = self.depthMap else {
            print("Depth image pixel buffer is nil")
            return 0.0
        }
        guard let segmentationLabelMap = segmentationLabelImage.pixelBuffer else {
            print("Segmentation label image pixel buffer is nil")
            return 0.0
        }
        
        var sumX = 0
        var sumY = 0
        var numPixels = 0
        
        CVPixelBufferLockBaseAddress(segmentationLabelMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(segmentationLabelMap, .readOnly) }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        /// Get the pixel buffer dimensions
        let segmentationLabelWidth = CVPixelBufferGetWidth(segmentationLabelMap)
        let segmentationLabelHeight = CVPixelBufferGetHeight(segmentationLabelMap)
        
        guard segmentationLabelWidth == depthMapWidth && segmentationLabelHeight == depthMapHeight else {
            print("Segmentation label image and depth image dimensions do not match")
            return 0.0
        }
        
        /// Create a mask from the segmentation label image and the depth image
        guard let segmentationLabelBaseAddress = CVPixelBufferGetBaseAddress(segmentationLabelMap),
                let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return 0.0
        }
        let segmentationLabelBytesPerRow = CVPixelBufferGetBytesPerRow(segmentationLabelMap)
        let segmentationLabelBuffer = segmentationLabelBaseAddress.assumingMemoryBound(to: UInt8.self)
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let depthBuffer = depthBaseAddress.assumingMemoryBound(to: Float.self)
        
        /// Access each index of the segmentation label image
        for y in 0..<segmentationLabelHeight {
            for x in 0..<segmentationLabelWidth {
                let pixelOffset = y * segmentationLabelBytesPerRow + x
                let pixelValue = segmentationLabelBuffer[pixelOffset]
                if pixelValue == classLabel {
                    numPixels += 1
                    sumX += x
                    sumY += y
                }
            }
        }
        
        guard numPixels > 0 else {
            print("No pixels found for class label \(classLabel)")
            return 0.0
        }
        numPixels = numPixels == 0 ? 1 : numPixels
        let gravityX = floor(Double(sumX) / Double(numPixels))
        let gravityY = floor(Double(sumY) / Double(numPixels))
//        print("gravityX: \(gravityX), gravityY: \(gravityY)")
        let gravityPixelOffset = Int(gravityY) * depthBytesPerRow / MemoryLayout<Float>.size + Int(gravityX)
        return depthBuffer[gravityPixelOffset]
    }
    
    /**
     This function calculates the depth value of the object at the centroid of the segmented image.
     
     NOTE: It takes the segmentation label image only for getting the dimensions of the image for verification and offset calculation.
     
        The depth image is not used in this function.
     */
    func getDepth(segmentationLabelImage: CIImage, object: DetectedObject?, depthImage: CIImage, classLabel: UInt8) -> Float {
        guard let object = object else {
            print("Object is nil")
            return self.getDepth(segmentationLabelImage: segmentationLabelImage, depthImage: depthImage, classLabel: classLabel)
        }
        guard let depthMap = self.depthMap else {
            print("Depth image pixel buffer is nil")
            return 0.0
        }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let segmentationLabelWidth = segmentationLabelImage.extent.width
        let segmentationLabelHeight = segmentationLabelImage.extent.height
        
        guard Int(segmentationLabelWidth) == depthMapWidth && Int(segmentationLabelHeight) == depthMapHeight else {
            print("Segmentation label image and depth image dimensions do not match")
            return 0.0
        }
        
        guard let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return 0.0
        }
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let depthBuffer = depthBaseAddress.assumingMemoryBound(to: Float.self)
        
        // Flip the y part of the centroid, since it comes from Core Vision and is in the bottom-left coordinate system
        // unlike a CVPixelBuffer, which when manually accessed, is in the top-left coordinate system.
        let objectGravityPoint: CGPoint = CGPoint(x: object.centroid.x * segmentationLabelWidth,
                                              y: (1 - object.centroid.y) * segmentationLabelHeight)
//        print("objectCentroid: \(objectGravityPoint)")
        let gravityPixelOffset = Int(objectGravityPoint.y) * depthBytesPerRow / MemoryLayout<Float>.size + Int(objectGravityPoint.x)
        return depthBuffer[gravityPixelOffset]
    }
    
    /**
     This function calculates the depth value of the object by averaging the depth values of the pixels in a radius around the centroid of the segmented image.
     
     NOTE: This uses the segmentation label image not only for getting image dimensions, but also to verify if a given pixel is part of the object.
     
        The depth image is not used in this function.
     */
    func getDepthInRadius(segmentationLabelImage: CIImage, object: DetectedObject?, depthRadius: Int = 5,
                          depthImage: CIImage, classLabel: UInt8) -> Float {
        guard let object = object else {
            print("Object is nil")
            return self.getDepth(segmentationLabelImage: segmentationLabelImage, depthImage: depthImage, classLabel: classLabel)
        }
        guard let depthMap = self.depthMap else {
            print("Depth image pixel buffer is nil")
            return 0.0
        }
        guard let segmentationLabelMap = segmentationLabelImage.pixelBuffer else {
            print("Segmentation label image pixel buffer is nil")
            return 0.0
        }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        CVPixelBufferLockBaseAddress(segmentationLabelMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(segmentationLabelMap, .readOnly) }
        
        let segmentationLabelWidth = segmentationLabelImage.extent.width
        let segmentationLabelHeight = segmentationLabelImage.extent.height
        
        guard Int(segmentationLabelWidth) == depthMapWidth && Int(segmentationLabelHeight) == depthMapHeight else {
            print("Segmentation label image and depth image dimensions do not match")
            return 0.0
        }
        
        guard let segmentationLabelBaseAddress = CVPixelBufferGetBaseAddress(segmentationLabelMap),
                let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return 0.0
        }
        let segmentationLabelBytesPerRow = CVPixelBufferGetBytesPerRow(segmentationLabelMap)
        let segmentationLabelBuffer = segmentationLabelBaseAddress.assumingMemoryBound(to: UInt8.self)
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let depthBuffer = depthBaseAddress.assumingMemoryBound(to: Float.self)
        
        // Calculate the radius points
        let deltas = (-depthRadius...depthRadius).flatMap { dx in
            (-depthRadius...depthRadius).map { dy in
                CGPoint(x: dx, y: dy)
            }
        }
        var depths: [Float] = []
        for delta in deltas {
            // Flip the y part of the centroid, since it comes from Core Vision and is in the bottom-left coordinate system
            // unlike a CVPixelBuffer, which when manually accessed, is in the top-left coordinate system.
            let point = CGPoint(x: object.centroid.x * segmentationLabelWidth + delta.x,
                                y: (1 - object.centroid.y) * segmentationLabelHeight + delta.y)
            // Check if the point is within bounds of the segmentation label image
            guard point.x >= 0 && point.x < CGFloat(segmentationLabelWidth) &&
                    point.y >= 0 && point.y < CGFloat(segmentationLabelHeight) else {
                print("Point is out of bounds: \(point)")
                continue
            }
            // Check if the point is part of the object in the segmentation label image
            let segmentationPixelOffset = Int(point.y) * segmentationLabelBytesPerRow / MemoryLayout<UInt8>.size + Int(point.x)
            let segmentationPixelValue = segmentationLabelBuffer[segmentationPixelOffset]
            guard segmentationPixelValue == classLabel else {
                continue
            }
            // Calculate the depth value at this point
            let depthPixelOffset = Int(point.y) * depthBytesPerRow / MemoryLayout<Float>.size + Int(point.x)
            let depthValue = depthBuffer[depthPixelOffset]
            // Add the depth value to the list
            depths.append(depthValue)
        }
        // TODO: The following fallback exists in case no depths are found in the radius.
        // This is why trimmed mean should be eventually used as the main method for calculating depth.
        if depths.isEmpty {
            // Flip the y part of the centroid, since it comes from Core Vision and is in the bottom-left coordinate system
            // unlike a CVPixelBuffer, which when manually accessed, is in the top-left coordinate system.
            let point: CGPoint = CGPoint(x: object.centroid.x * segmentationLabelWidth,
                                         y: (1 - object.centroid.y) * segmentationLabelHeight)
            //        print("objectCentroid: \(objectGravityPoint)")
            let depthPixelOffset = Int(point.y) * depthBytesPerRow / MemoryLayout<Float>.size + Int(point.x)
            let depthValue = depthBuffer[depthPixelOffset]
            depths.append(depthValue)
        }
        
        // Calculate the mean depth value
        let meanDepth = depths.reduce(0, +) / Float(depths.count)
        return meanDepth
    }
        
}

/**
 Helper functions to get specific pixel values from the depth map.
 */
extension DepthMapProcessor {
    func getDepthImageDimensions() -> (width: Int, height: Int) {
        return (depthMapWidth, depthMapHeight)
    }
    
    func getValues(at points: [CGPoint]) -> [Float]? {
        guard let depthMap = self.depthMap else {
            print("Depth image pixel buffer is nil")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        
        guard let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return nil
        }
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let depthBuffer = depthBaseAddress.assumingMemoryBound(to: Float.self)
        
        var values: [Float] = []
        for point in points {
            guard point.x >= 0 && point.x < CGFloat(depthWidth) && point.y >= 0 && point.y < CGFloat(depthHeight) else {
                print("Point is out of bounds")
                values.append(0.0)
                continue
            }
            let x = Int(point.x)
//            let y = Int(point.y)
            // Flip the y part of the centroid, since it comes from Core Vision/Graphics and is in the bottom-left coordinate system
            // unlike a CVPixelBuffer, which when manually accessed, is in the top-left coordinate system.
            let y = Int(Float(depthHeight) - Float(point.y))
            let pixelOffset = y * depthBytesPerRow / MemoryLayout<Float>.size + x
            values.append(depthBuffer[pixelOffset])
        }
        return values
    }
    
    func getDepthValuesInRadius(segmentationLabelImage: CIImage, at points: [CGPoint],
                                depthRadius: Int = 5, depthImage: CIImage, classLabel: UInt8) -> [Float]? {
        guard let depthMap = self.depthMap else {
            print("Depth image pixel buffer is nil")
            return nil
        }
        guard let segmentationLabelMap = segmentationLabelImage.pixelBuffer else {
            print("Segmentation label image pixel buffer is nil")
            return nil
        }
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        CVPixelBufferLockBaseAddress(segmentationLabelMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(segmentationLabelMap, .readOnly) }
        
        let segmentationLabelWidth = segmentationLabelImage.extent.width
        let segmentationLabelHeight = segmentationLabelImage.extent.height
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        
        guard Int(segmentationLabelWidth) == depthMapWidth && Int(segmentationLabelHeight) == depthMapHeight else {
            print("Segmentation label image and depth image dimensions do not match")
            return nil
        }
        
        guard let segmentationLabelBaseAddress = CVPixelBufferGetBaseAddress(segmentationLabelMap),
                let depthBaseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
            return nil
        }
        let segmentationLabelBytesPerRow = CVPixelBufferGetBytesPerRow(segmentationLabelMap)
        let segmentationLabelBuffer = segmentationLabelBaseAddress.assumingMemoryBound(to: UInt8.self)
        let depthBytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
        let depthBuffer = depthBaseAddress.assumingMemoryBound(to: Float.self)
        
        var depthValues: [Float] = []
        for point in points {
            // Calculate the radius points
            let deltas = (-depthRadius...depthRadius).flatMap { dx in
                (-depthRadius...depthRadius).map { dy in
                    CGPoint(x: dx, y: dy)
                }
            }
            var depths: [Float] = []
            for delta in deltas {
                // Check if the point is within bounds of the segmentation label image
                guard point.x >= 0 && point.x < CGFloat(segmentationLabelWidth) &&
                        point.y >= 0 && point.y < CGFloat(segmentationLabelHeight) else {
                    print("Point is out of bounds: \(point)")
                    continue
                }
                let x = Int(point.x)
                // Flip the y part of the centroid, since it comes from Core Vision/Graphics and is in the bottom-left coordinate system
                // unlike a CVPixelBuffer, which when manually accessed, is in the top-left coordinate system.
                let y = Int(Float(depthHeight) - Float(point.y))
                // Check if the point is part of the object in the segmentation label image
                let segmentationPixelOffset = y * segmentationLabelBytesPerRow / MemoryLayout<UInt8>.size + x
                let segmentationPixelValue = segmentationLabelBuffer[segmentationPixelOffset]
                guard segmentationPixelValue == classLabel else {
                    continue
                }
                // Calculate the depth value at this point
                let depthPixelOffset = y * depthBytesPerRow / MemoryLayout<Float>.size + x
                let depthValue = depthBuffer[depthPixelOffset]
                // Add the depth value to the list
                depths.append(depthValue)
            }
            // TODO: The following fallback exists in case no depths are found in the radius.
            // This is why trimmed mean should be eventually used as the main method for calculating depth.
            if depths.isEmpty {
                let x = Int(point.x)
                // Flip the y part of the centroid, since it comes from Core Vision/Graphics and is in the bottom-left coordinate system
                // unlike a CVPixelBuffer, which when manually accessed, is in the top-left coordinate system.
                let y = Int(Float(depthHeight) - Float(point.y))
                let depthPixelOffset = y * depthBytesPerRow / MemoryLayout<Float>.size + x
                let depthValue = depthBuffer[depthPixelOffset]
                depths.append(depthValue)
            }
            
            // Calculate the mean depth value
            let meanDepth = depths.reduce(0, +) / Float(depths.count)
            depthValues.append(meanDepth)
        }
        return depthValues
    }
}

/**
    Helper functions for creating a pixel buffer from a CIImage. Will be removed in the future.
 */
extension DepthMapProcessor {
    func createMask(from image: CIImage, classLabel: UInt8) -> [[Int]] {
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return [] }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerPixel = 1
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var pixelData = [UInt8](repeating: 0, count: width * height)
        
        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return []
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var mask = [[Int]](repeating: [Int](repeating: 0, count: width), count: height)
        
        var uniqueValues = Set<UInt8>()
        for row in 0..<height {
            for col in 0..<width {
                let pixelIndex = row * width + col
                let pixelValue = pixelData[pixelIndex]
                mask[row][col] = pixelValue == classLabel ? 0 : 1
                uniqueValues.insert(pixelValue)
            }
        }
        print("uniqueValues: \(uniqueValues)")
        return mask
    }
}
