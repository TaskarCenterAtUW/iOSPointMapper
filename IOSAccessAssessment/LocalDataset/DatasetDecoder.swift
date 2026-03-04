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

enum DatasetDecoderError: Error, LocalizedError {
    case directoryRetrievalFailed
    
    var errorDescription: String? {
        switch self {
        case .directoryRetrievalFailed:
            return "Failed to retrieve dataset directory."
        }
    }
}

/**
    Encoder for saving dataset frames and metadata.
 
    This encoder saves RGB, depth, and segmentation images along with camera intrinsics, location, and other details.
    Finally, it also adds a node to TDEI workspaces at the capture location.
 */
class DatasetDecoder {
    private var workspaceId: String
    
    private var workspaceDirectory: URL
    private var datasetDirectory: URL
    private var savedFrames: Int = 0
    
    public let rgbFilePath: URL /// Relative to app document directory.
    public let depthFilePath: URL /// Relative to app document directory.
    public let cameraIntrinsicsPath: URL
    public let cameraMatrixPath: URL
    public let cameraTransformPath: URL
    public let locationPath: URL
//    public let headingPath: URL
    public let otherDetailsPath: URL
    
    private let rgbDecoder: RGBDecoder
    private let depthDecoder: DepthDecoder
    private let cameraIntrinsicsDecoder: CameraIntrinsicsDecoder
    private let cameraTransformDecoder: CameraTransformDecoder
    private let locationDecoder: LocationDecoder
//    private let headingDecoder: HeadingDecoder
    private let otherDetailsDecoder: OtherDetailsDecoder
    
    init(workspaceId: String, changesetId: String) throws {
        self.workspaceId = workspaceId
        
        /// Get workspace directory
        self.workspaceDirectory = try DatasetDecoder.findDirectory(id: workspaceId)
        /// Get dataset directory
        self.datasetDirectory = try DatasetDecoder.findDirectory(id: changesetId, relativeTo: self.workspaceDirectory)
        
        self.rgbFilePath = datasetDirectory.appendingPathComponent("rgb", isDirectory: true)
        self.depthFilePath = datasetDirectory.appendingPathComponent("depth", isDirectory: true)
        self.cameraIntrinsicsPath = datasetDirectory.appendingPathComponent("camera_intrinsics.csv", isDirectory: false)
        self.cameraMatrixPath = datasetDirectory.appendingPathComponent("camera_matrix.csv", isDirectory: false)
        self.cameraTransformPath = datasetDirectory.appendingPathComponent("camera_transform.csv", isDirectory: false)
        self.locationPath = datasetDirectory.appendingPathComponent("location.csv", isDirectory: false)
//        self.headingPath = datasetDirectory.appendingPathComponent("heading.csv", isDirectory: false)
        self.otherDetailsPath = datasetDirectory.appendingPathComponent("other_details.csv", isDirectory: false)
        
        self.rgbDecoder = RGBDecoder(inDirectory: self.rgbFilePath)
        self.depthDecoder = DepthDecoder(inDirectory: self.depthFilePath)
        self.cameraIntrinsicsDecoder = try CameraIntrinsicsDecoder(path: self.cameraIntrinsicsPath)
        self.cameraTransformDecoder = try CameraTransformDecoder(path: self.cameraTransformPath)
        self.locationDecoder = try LocationDecoder(path: self.locationPath)
//        self.headingDecoder = HeadingDecoder(url: self.headingPath)
        self.otherDetailsDecoder = try OtherDetailsDecoder(path: self.otherDetailsPath)
    }
    
    static private func findDirectory(id: String, relativeTo: URL? = nil) throws -> URL {
        var relativeTo = relativeTo
        if relativeTo == nil {
            guard let relativeToUrl = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first else {
                throw DatasetDecoderError.directoryRetrievalFailed
            }
            relativeTo = relativeToUrl
        }
        let directory = URL(filePath: id, directoryHint: .isDirectory, relativeTo: relativeTo)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw DatasetDecoderError.directoryRetrievalFailed
        }
        return directory
    }
    
    
}
