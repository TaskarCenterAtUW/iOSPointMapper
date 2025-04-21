//
//  ObjectLocation.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/04/29.
//

import SwiftUI
import UIKit
import AVFoundation
import CoreImage
import CoreLocation

// TODO: As pointed out in the TODO for the ContentView objectLocation
// We would want to separate out device location logic, and pixel-wise location calculation logic
class ObjectLocation {
    var locationManager: CLLocationManager
    var longitude: CLLocationDegrees?
    var latitude: CLLocationDegrees?
    var headingDegrees: CLLocationDirection?
    
    let ciContext = CIContext(options: nil)
    
    init() {
        self.locationManager = CLLocationManager()
        self.longitude = nil
        self.latitude = nil
        self.headingDegrees = nil
        self.setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    private func setLocation() {
        if let location = locationManager.location {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
        }
    }
    
    private func setHeading() {
        if let heading = locationManager.heading {
            self.headingDegrees = heading.magneticHeading
//            headingStatus = "Heading: \(headingDegrees) degrees"
        }
    }
    
    func setLocationAndHeading() {
        setLocation()
        setHeading()
        
        guard let _ = self.latitude, let _ = self.longitude else {
            print("latitude or longitude: nil")
            return
        }
        
        guard let _ = self.headingDegrees else {
            print("heading: nil")
            return
        }
    }
    
    func calcLocation(segmentationLabelImage: CIImage, depthImage: CIImage, classLabel: UInt8) {
        let depthValue = getDepth(segmentationLabelImage: segmentationLabelImage, depthImage: depthImage, classLabel: classLabel)
//        guard depthValue != 0.0 else {
//            print("depth: nil")
//            return
//        }
        print("depth: \(depthValue)")
        
        // FIXME: Setting the location for every segment means that there is potential for errors
        //  If the user moves while validating each segment, would every segment get different device location?
        setLocation()
        setHeading()

        guard let latitude = self.latitude, let longitude = self.longitude, let heading = self.headingDegrees else {
            print("latitude, longitude, or heading: nil")
            return
        }

        // Calculate the object's coordinates assuming a flat plane
        let distance = depthValue
        let bearing = heading * .pi / 180.0 // Convert to radians

        // Calculate the change in coordinates
        let deltaX = Double(distance) * cos(Double(bearing))
        let deltaY = Double(distance) * sin(Double(bearing))

        // Assuming 1 degree of latitude and longitude is approximately 111,000 meters
        let metersPerDegree = 111_000.0

        let objectLatitude = latitude + (deltaY / metersPerDegree)
        let objectLongitude = longitude + (deltaX / metersPerDegree)

        print("Object coordinates: latitude: \(objectLatitude), longitude: \(objectLongitude)")
    }
}

/**
 Helper functions for calculating the depth value of the object at the centroid of the segmented image.
 Will be replaced with a function that utilizes obtained object polyons to calculate the depth value at the centroid of the polygon.
 */
extension ObjectLocation {
    // FIXME: Use something like trimmed mean to eliminate outliers, instead of the normal mean
    /**
        This function calculates the depth value of the object at the centroid of the segmented image.
     
        segmentationLabelImage: The segmentation label image (pixel format: kCVPixelFormatType_OneComponent8)

        depthImage: The depth image (pixel format: kCVPixelFormatType_DepthFloat32)
     */
    func getDepth(segmentationLabelImage: CIImage, depthImage: CIImage, classLabel: UInt8) -> Float {
        guard let segmentationLabelMap = segmentationLabelImage.pixelBuffer else {
            print("Segmentation label image pixel buffer is nil")
            return 0.0
        }
        /// Create depthMap which is not backed by a pixel buffer
        guard let depthMap = createPixelBuffer(width: Int(depthImage.extent.width), height: Int(depthImage.extent.height)) else {
            print("Depth image pixel buffer is nil")
            return 0.0
        }
        ciContext.render(depthImage, to: depthMap)
            
//        var distanceSum: Float = 0
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
        
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        
        print("segmentationLabelWidth: \(segmentationLabelWidth), segmentationLabelHeight: \(segmentationLabelHeight)")
        print("depthWidth: \(depthWidth), depthHeight: \(depthHeight)")
        
        guard segmentationLabelWidth == depthWidth && segmentationLabelHeight == depthHeight else {
            print("Segmentation label image and depth image dimensions do not match")
            return 0.0
        }
        
        /// Create a mask from the segmentation label image
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
        
        // In case there is not a single pixel of that class
        // MARK: We would want a better way to handle this edge case, where we do not pass any information about the object
        // Else, this code will pass the depth info of location (0, 0)
        numPixels = numPixels == 0 ? 1 : numPixels
        let gravityX = floor(Double(sumX) / Double(numPixels))
        let gravityY = floor(Double(sumY) / Double(numPixels))
        let gravityPixelOffset = Int(gravityY) * depthBytesPerRow / MemoryLayout<Float>.size + Int(gravityX)
        print("gravityX: \(gravityX), gravityY: \(gravityY), numPixels: \(numPixels)")
        print("gravityPixelOffset: \(gravityPixelOffset). Depth Value at centroid: \(depthBuffer[gravityPixelOffset])")
        return depthBuffer[gravityPixelOffset]
    }
    
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
