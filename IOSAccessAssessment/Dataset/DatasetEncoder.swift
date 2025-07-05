//
//  DatasetEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation
import ARKit
import CryptoKit
import CoreLocation

enum DatasetEncoderStatus {
    case allGood
    case videoEncodingError
    case directoryCreationError
}

class DatasetEncoder {
    private var datasetDirectory: URL
    private var savedFrames: Int = 0
    
    public let rgbFilePath: URL // Relative to app document directory.
    public let depthFilePath: URL // Relative to app document directory.
//    public let confidenceFilePath: URL // Relative to app document directory.
    public let cameraMatrixPath: URL
    public let cameraTransformPath: URL
    public let locationPath: URL
    public let headingPath: URL
    
    private let rgbEncoder: RGBEncoder
    private let depthEncoder: DepthEncoder
//    private let confidenceEncoder: ConfidenceEncoder
    private let cameraTransformEncoder: CameraTransformEncoder
    private let locationEncoder: LocationEncoder
    private let headingEncoder: HeadingEncoder
    
    public var status = DatasetEncoderStatus.allGood
    public var capturedFrameIds: Set<UUID> = []
    
    init(changesetId: String) {
        self.datasetDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        datasetDirectory = DatasetEncoder.createDirectory(id: changesetId)
        self.rgbFilePath = datasetDirectory.appendingPathComponent("rgb", isDirectory: true)
        self.depthFilePath = datasetDirectory.appendingPathComponent("depth", isDirectory: true)
//        self.confidenceFilePath = datasetDirectory.appendingPathComponent("confidence", isDirectory: true)
        self.cameraMatrixPath = datasetDirectory.appendingPathComponent("camera_matrix.csv", isDirectory: false)
        self.cameraTransformPath = datasetDirectory.appendingPathComponent("camera_transform.csv", isDirectory: false)
        self.locationPath = datasetDirectory.appendingPathComponent("location.csv", isDirectory: false)
        self.headingPath = datasetDirectory.appendingPathComponent("heading.csv", isDirectory: false)
        
        self.rgbEncoder = RGBEncoder(outDirectory: self.rgbFilePath)
        self.depthEncoder = DepthEncoder(outDirectory: self.depthFilePath)
//        self.confidenceEncoder = ConfidenceEncoder(outDirectory: self.confidenceFilePath)
        self.cameraTransformEncoder = CameraTransformEncoder(url: self.cameraTransformPath)
        self.locationEncoder = LocationEncoder(url: self.locationPath)
        self.headingEncoder = HeadingEncoder(url: self.headingPath)
    }
    
    static private func createDirectory(id: String) -> URL {
        let url = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first!
        var directory = URL(filePath: id, directoryHint: .isDirectory, relativeTo: url)
        if FileManager.default.fileExists(atPath: directory.path) {
            // Return existing directory if it already exists
            return directory
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            print("Error creating directory. \(error), \(error.userInfo)")
        }
        return directory
    }
    
    public func addData(
        frameId: UUID,
        cameraImage: CIImage, depthImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        location: CLLocation?, heading: CLHeading? = nil,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        if (self.capturedFrameIds.contains(frameId)) {
            print("Frame with ID \(frameId) already exists. Skipping.")
            return
        }
        
        let frameNumber: UUID = frameId
        
        self.rgbEncoder.save(ciImage: cameraImage, frameNumber: frameNumber)
        self.depthEncoder.save(ciImage: depthImage, frameNumber: frameNumber)
//        self.confidenceEncoder.save(ciImage: confidenceImage, frameNumber: frameNumber)
        self.cameraTransformEncoder.add(transform: cameraTransform, timestamp: timestamp, frameNumber: frameNumber)
        self.writeIntrinsics(cameraIntrinsics: cameraIntrinsics)
        
        let locationData = LocationData(timestamp: timestamp, latitude: location?.coordinate.latitude ?? 0.0,
                                        longitude: location?.coordinate.longitude ?? 0.0)
        let headingData = HeadingData(timestamp: timestamp, magneticHeading: heading?.magneticHeading ?? 0.0,
                                      trueHeading: heading?.trueHeading ?? 0.0)
        self.locationEncoder.add(locationData: locationData, frameNumber: frameNumber)
        self.headingEncoder.add(headingData: headingData, frameNumber: frameNumber)
        
        savedFrames = savedFrames + 1
        self.capturedFrameIds.insert(frameNumber)
    }
    
    private func writeIntrinsics(cameraIntrinsics: simd_float3x3) {
        let rows = cameraIntrinsics.transpose.columns
        var csv: [String] = []
        for row in [rows.0, rows.1, rows.2] {
            let csvLine = "\(row.x), \(row.y), \(row.z)"
            csv.append(csvLine)
        }
        let contents = csv.joined(separator: "\n")
        do {
            try contents.write(to: self.cameraMatrixPath, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            print("Could not write camera matrix. \(error.localizedDescription)")
        }
    }
}
