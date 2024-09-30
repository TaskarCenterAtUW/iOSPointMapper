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


class ObjectLocation {
    var depthValue: Float?
    var locationManager: CLLocationManager
    var longitude: CLLocationDegrees?
    var latitude: CLLocationDegrees?
    var headingDegrees: CLLocationDirection?
    
    init() {
        self.depthValue = nil
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
    
    private func handleLocationUpdate() {
        if let location = locationManager.location {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
        }
    }
    
    private func handleHeadingUpdate() {
        if let heading = locationManager.heading {
            self.headingDegrees = heading.magneticHeading
//            headingStatus = "Heading: \(headingDegrees) degrees"
        }
    }
    
    func settingLocation() {
        handleLocationUpdate()
        handleHeadingUpdate()
        
        guard let latitude = self.latitude, let longitude = self.longitude else {
            print("latitude or longitude: nil")
            return
        }
        print("latitude: \(latitude), longitude: \(longitude)")
        
        guard let heading = self.headingDegrees else {
            print("heading: nil")
            return
        }
        print("heading: \(heading)")
    }
    
    func calcLocation(sharedImageData: SharedImageData, index: Int) {
        getDepth(sharedImageData: sharedImageData, index: index)
        guard let depth = self.depthValue else {
            print("depth: nil")
            return
        }
        print("depth: \(depth)")

        handleLocationUpdate()
        handleHeadingUpdate()

        guard let latitude = self.latitude, let longitude = self.longitude, let heading = self.headingDegrees else {
            print("latitude, longitude, or heading: nil")
            return
        }

        // Calculate the object's coordinates assuming a flat plane
        let distance = depth
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
    
    func createMask(from image: CIImage) -> [[Int]] {
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
        for row in 0..<height {
            for col in 0..<width {
                let pixelIndex = row * width + col
                let pixelValue = pixelData[pixelIndex]
                mask[row][col] = Int(pixelValue) == 0 ? 0 : 1
            }
        }
        return mask
    }
    
    func getDepth(sharedImageData: SharedImageData, index: Int) {
        let objectSegmentation = sharedImageData.classImages[index]
        let mask = createMask(from: objectSegmentation)
        guard let depthMap = sharedImageData.depthData else { return }
//        var distanceSum: Float = 0
        var sumX = 0
        var sumY = 0
        var numPixels = 0
        
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = mask[0].count
        let height = mask.count
        
        let depthWidth = CVPixelBufferGetWidth(depthMap)
        let depthHeight = CVPixelBufferGetHeight(depthMap)
        
        if let baseAddress = CVPixelBufferGetBaseAddress(depthMap) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
            let floatBuffer = baseAddress.assumingMemoryBound(to: Float.self)
            
            for y in 0..<height {
                for x in 0..<width {
                    if mask[y][x] == 1 {
                        numPixels += 1
                        sumX += x
                        sumY += y
                    }
                }
            }
            let gravityX = floor(Double(sumX) * 4 / Double(numPixels))
            let gravityY = floor(Double(sumY) * 4 / Double(numPixels))
            let pixelOffset = Int(gravityY) * bytesPerRow / MemoryLayout<Float>.size + Int(gravityX)
            depthValue = floatBuffer[pixelOffset]
        }
    }
}
