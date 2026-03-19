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
    case indexDataNotFound(Int)
    
    var errorDescription: String? {
        switch self {
        case .directoryRetrievalFailed:
            return "Failed to retrieve dataset directory."
        case .indexDataNotFound(let index):
            return "Data for index \(index) not found."
        }
    }
}

struct DatasetCaptureBaseData: CaptureDataProtocol {
    let id: UUID
    let timestamp: TimeInterval
    
    let cameraImage: CIImage
    let cameraTransform: simd_float4x4
    let cameraIntrinsics: simd_float3x3
    
    let interfaceOrientation: UIInterfaceOrientation
    let originalSize: CGSize
    
    let depthImage: CIImage?
    let confidenceImage: CIImage?
}

struct DatasetCaptureData {
    let captureImageData: DatasetCaptureBaseData
    let captureMeshData: MeshContents?
    let location: CLLocationCoordinate2D?
    let heading: CLLocationDirection?
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
    var totalFrames: Int = 0
    
    public let rgbFilePath: URL /// Relative to app document directory.
    public let depthFilePath: URL /// Relative to app document directory.
    public let cameraIntrinsicsPath: URL
//    public let cameraMatrixPath: URL
    public let cameraTransformPath: URL
    public let locationPath: URL
    public let headingPath: URL
    public let otherDetailsPath: URL
    public let meshPath: URL
    
    private let rgbDecoder: RGBDecoder
    private let depthDecoder: DepthDecoder
    private let cameraIntrinsicsDecoder: CameraIntrinsicsDecoder
    private let cameraTransformDecoder: CameraTransformDecoder
    private let locationDecoder: LocationDecoder
    private let headingDecoder: HeadingDecoder
    private let otherDetailsDecoder: OtherDetailsDecoder
    private let meshDecoder: MeshDecoder
    
    init(workspaceId: String, changesetId: String) throws {
        self.workspaceId = workspaceId
        
        /// Get workspace directory
        self.workspaceDirectory = try DatasetDecoder.findDirectory(id: workspaceId)
        /// Get dataset directory
        self.datasetDirectory = try DatasetDecoder.findDirectory(id: changesetId, relativeTo: self.workspaceDirectory)
        
        self.rgbFilePath = datasetDirectory.appendingPathComponent("rgb", isDirectory: true)
        self.depthFilePath = datasetDirectory.appendingPathComponent("depth", isDirectory: true)
        self.cameraIntrinsicsPath = datasetDirectory.appendingPathComponent("camera_intrinsics.csv", isDirectory: false)
//        self.cameraMatrixPath = datasetDirectory.appendingPathComponent("camera_matrix.csv", isDirectory: false)
        self.cameraTransformPath = datasetDirectory.appendingPathComponent("camera_transform.csv", isDirectory: false)
        self.locationPath = datasetDirectory.appendingPathComponent("location.csv", isDirectory: false)
        self.headingPath = datasetDirectory.appendingPathComponent("heading.csv", isDirectory: false)
        self.otherDetailsPath = datasetDirectory.appendingPathComponent("other_details.csv", isDirectory: false)
        self.meshPath = datasetDirectory.appendingPathComponent("mesh", isDirectory: true)
        
        self.rgbDecoder = RGBDecoder(inDirectory: self.rgbFilePath)
        self.depthDecoder = DepthDecoder(inDirectory: self.depthFilePath)
        self.cameraIntrinsicsDecoder = try CameraIntrinsicsDecoder(path: self.cameraIntrinsicsPath)
        self.cameraTransformDecoder = try CameraTransformDecoder(path: self.cameraTransformPath)
        self.locationDecoder = try LocationDecoder(path: self.locationPath)
        self.headingDecoder = try HeadingDecoder(url: self.headingPath)
        self.otherDetailsDecoder = try OtherDetailsDecoder(path: self.otherDetailsPath)
        self.meshDecoder = MeshDecoder(inDirectory: self.meshPath)
        
        self.totalFrames = self.cameraIntrinsicsDecoder.results.count
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
    
    func loadData(index: Int, enhancedAnalysisMode: Bool = false) throws -> DatasetCaptureData {
        /// Use the camera intrinsics data as the source of truth for getting the frame for a specific index
        let cameraIntrinsicsResults = self.cameraIntrinsicsDecoder.results
        guard index < cameraIntrinsicsResults.count else {
            throw DatasetDecoderError.indexDataNotFound(index)
        }
        let frameNumber = cameraIntrinsicsResults[index].frame
        
        let cameraImage: CIImage = try rgbDecoder.load(frameNumber: frameNumber)
        let depthBuffer: CVPixelBuffer = try depthDecoder.decodeFrame(frameNumber: frameNumber)
        let depthImage: CIImage = CIImage(cvPixelBuffer: depthBuffer)
        guard let cameraIntrinsics = cameraIntrinsicsDecoder.load(index: index, frameNumber: frameNumber)?.intrinsics else {
            throw DatasetDecoderError.indexDataNotFound(index)
        }
        guard let cameraTransform = cameraTransformDecoder.load(index: index, frameNumber: frameNumber)?.transform else {
            throw DatasetDecoderError.indexDataNotFound(index)
        }
        guard let locationData = locationDecoder.load(index: index, frameNumber: frameNumber) else {
            throw DatasetDecoderError.indexDataNotFound(index)
        }
        guard let headingData = headingDecoder.load(index: index, frameNumber: frameNumber) else {
            throw DatasetDecoderError.indexDataNotFound(index)
        }
        guard let otherDetailsData = otherDetailsDecoder.load(index: index, frameNumber: frameNumber) else {
            throw DatasetDecoderError.indexDataNotFound(index)
        }
        var meshContents: MeshContents? = nil
        if enhancedAnalysisMode {
            /// In enhanced analysis mode, we also load the mesh data for the frame if it exists.
            meshContents = try? meshDecoder.load(frameNumber: frameNumber)
        }
        
        let datasetCaptureBaseData = DatasetCaptureBaseData(
            id: frameNumber, timestamp: cameraIntrinsicsResults[index].timestamp,
            cameraImage: cameraImage, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics,
            interfaceOrientation: otherDetailsData.deviceOrientation, originalSize: otherDetailsData.originalSize,
            depthImage: depthImage, confidenceImage: nil
        )
        let location = CLLocationCoordinate2D(latitude: locationData.latitude, longitude: locationData.longitude)
        let heading = headingData.trueHeading
        let datasetCaptureData = DatasetCaptureData(
            captureImageData: datasetCaptureBaseData,
            captureMeshData: meshContents,
            location: location,
            heading: heading
        )
        return datasetCaptureData
    }
}
