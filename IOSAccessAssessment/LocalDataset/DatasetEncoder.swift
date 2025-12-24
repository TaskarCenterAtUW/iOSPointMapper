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

/**
    Encoder for saving dataset frames and metadata.
 
    This encoder saves RGB, depth, and segmentation images along with camera intrinsics, location, and other details.
    Finally, it also adds a node to TDEI workspaces at the capture location.
 */
class DatasetEncoder {
    private var workspaceId: String
    
    private var workspaceDirectory: URL
    private var datasetDirectory: URL
    private var savedFrames: Int = 0
    
    public let rgbFilePath: URL /// Relative to app document directory.
    public let depthFilePath: URL /// Relative to app document directory.
    public let segmentationFilePath: URL /// Relative to app document directory.
    public let confidenceFilePath: URL /// Relative to app document directory.
    public let cameraIntrinsicsPath: URL
    public let cameraMatrixPath: URL
    public let cameraTransformPath: URL
    public let locationPath: URL
//    public let headingPath: URL
    public let otherDetailsPath: URL
    
    private let rgbEncoder: RGBEncoder
    private let depthEncoder: DepthEncoder
    private let segmentationEncoder: SegmentationEncoder
    private let confidenceEncoder: ConfidenceEncoder
    private let cameraIntrinsicsEncoder: CameraIntrinsicsEncoder
    private let cameraTransformEncoder: CameraTransformEncoder
    private let locationEncoder: LocationEncoder
//    private let headingEncoder: HeadingEncoder
    private let otherDetailsEncoder: OtherDetailsEncoder
    
    public var capturedFrameIds: Set<UUID> = []
    
    init(workspaceId: String, changesetId: String) throws {
        self.workspaceId = workspaceId
        
        /// Create workspace Directory if it doesn't exist
        self.workspaceDirectory = try DatasetEncoder.createDirectory(id: workspaceId)
        /// if workspace directory exists, create dataset directory inside it
        datasetDirectory = try DatasetEncoder.createDirectory(id: changesetId, relativeTo: self.workspaceDirectory)
        
        self.rgbFilePath = datasetDirectory.appendingPathComponent("rgb", isDirectory: true)
        self.depthFilePath = datasetDirectory.appendingPathComponent("depth", isDirectory: true)
        self.segmentationFilePath = datasetDirectory.appendingPathComponent("segmentation", isDirectory: true)
        self.confidenceFilePath = datasetDirectory.appendingPathComponent("confidence", isDirectory: true)
        self.cameraIntrinsicsPath = datasetDirectory.appendingPathComponent("camera_intrinsics.csv", isDirectory: false)
        self.cameraMatrixPath = datasetDirectory.appendingPathComponent("camera_matrix.csv", isDirectory: false)
        self.cameraTransformPath = datasetDirectory.appendingPathComponent("camera_transform.csv", isDirectory: false)
        self.locationPath = datasetDirectory.appendingPathComponent("location.csv", isDirectory: false)
//        self.headingPath = datasetDirectory.appendingPathComponent("heading.csv", isDirectory: false)
        self.otherDetailsPath = datasetDirectory.appendingPathComponent("other_details.csv", isDirectory: false)
        
        self.rgbEncoder = try RGBEncoder(outDirectory: self.rgbFilePath)
        self.depthEncoder = try DepthEncoder(outDirectory: self.depthFilePath)
        self.segmentationEncoder = try SegmentationEncoder(outDirectory: self.segmentationFilePath)
        self.confidenceEncoder = try ConfidenceEncoder(outDirectory: self.confidenceFilePath)
        self.cameraIntrinsicsEncoder = try CameraIntrinsicsEncoder(url: self.cameraIntrinsicsPath)
        self.cameraTransformEncoder = try CameraTransformEncoder(url: self.cameraTransformPath)
        self.locationEncoder = try LocationEncoder(url: self.locationPath)
//        self.headingEncoder = HeadingEncoder(url: self.headingPath)
        self.otherDetailsEncoder = try OtherDetailsEncoder(url: self.otherDetailsPath)
    }
    
    static private func createDirectory(id: String, relativeTo: URL? = nil) throws -> URL {
        var relativeTo = relativeTo
        if relativeTo == nil {
            relativeTo = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first!
        }
        let directory = URL(filePath: id, directoryHint: .isDirectory, relativeTo: relativeTo)
        if FileManager.default.fileExists(atPath: directory.path) {
            /// Return existing directory if it already exists
            return directory
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        return directory
    }
    
    public func addCaptureData(
        captureImageData: any CaptureImageDataProtocol,
        location: CLLocationCoordinate2D?
    ) throws {
        let otherDetailsData = OtherDetailsData(
            timestamp: captureImageData.timestamp,
            deviceOrientation: captureImageData.interfaceOrientation,
            originalSize: captureImageData.originalSize
        )
        try self.addData(
            frameId: captureImageData.id,
            cameraImage: captureImageData.cameraImage,
            depthImage: captureImageData.depthImage,
            confidenceImage: captureImageData.confidenceImage,
            segmentationLabelImage: captureImageData.captureImageDataResults.segmentationLabelImage,
            cameraTransform: captureImageData.cameraTransform,
            cameraIntrinsics: captureImageData.cameraIntrinsics,
            location: location,
//            heading: captureImageData.heading,
            otherDetails: otherDetailsData,
            timestamp: captureImageData.timestamp
        )
    }
    
    public func addData(
        frameId: UUID,
        cameraImage: CIImage,
        depthImage: CIImage?, confidenceImage: CIImage?,
        segmentationLabelImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        location: CLLocationCoordinate2D?,
//        heading: CLHeading?,
        otherDetails: OtherDetailsData?,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) throws {
        if (self.capturedFrameIds.contains(frameId)) {
            print("Frame with ID \(frameId) already exists. Skipping.")
            return
        }
        
        let frameNumber: UUID = frameId
        
        try self.rgbEncoder.save(ciImage: cameraImage, frameNumber: frameNumber)
        if let depthImage = depthImage, let depthBuffer = depthImage.pixelBuffer {
            try self.depthEncoder.encodeFrame(frame: depthBuffer, frameNumber: frameNumber)
        }
        try self.segmentationEncoder.save(ciImage: segmentationLabelImage, frameNumber: frameNumber)
        if let confidenceImage = confidenceImage {
            try self.confidenceEncoder.save(ciImage: confidenceImage, frameNumber: frameNumber)
        }
        try self.cameraIntrinsicsEncoder.add(intrinsics: cameraIntrinsics, timestamp: timestamp, frameNumber: frameNumber)
        try self.cameraTransformEncoder.add(transform: cameraTransform, timestamp: timestamp, frameNumber: frameNumber)
        
        if let location = location {
            let latitude = location.latitude
            let longitude = location.longitude
    //        let magneticHeading = heading?.magneticHeading ?? 0.0
    //        let trueHeading = heading?.trueHeading ?? 0.0
            let locationData = LocationData(timestamp: timestamp, latitude: latitude, longitude: longitude)
    //        let headingData = HeadingData(timestamp: timestamp, magneticHeading: magneticHeading, trueHeading: trueHeading)
            try self.locationEncoder.add(locationData: locationData, frameNumber: frameNumber)
    //        self.headingEncoder.add(headingData: headingData, frameNumber: frameNumber)
        }
        
        if let otherDetailsData = otherDetails {
            try self.otherDetailsEncoder.add(otherDetails: otherDetailsData, frameNumber: frameNumber)
        }
        
        /// TODO: Add error handling for each encoder
        
        savedFrames = savedFrames + 1
        self.capturedFrameIds.insert(frameNumber)
    }
    
    func save() throws {
        try self.cameraTransformEncoder.done()
        try self.locationEncoder.done()
//        self.headingEncoder.done()
    }
}
