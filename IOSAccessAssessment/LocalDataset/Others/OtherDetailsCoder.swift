//
//  OtherDetailsEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/7/25.
//

import Foundation
import Accelerate
import ARKit

struct OtherDetailsData {
    let timestamp: TimeInterval
    let deviceOrientation: UIInterfaceOrientation
    let originalSize: CGSize
}

enum OtherDetailsCoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    case fileNotFound
    case fileReadFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create other details file."
        case .dataWriteFailed:
            return "Failed to write details data to file."
        case .fileNotFound:
            return "Other details file not found."
        case .fileReadFailed:
            return "Failed to read other details data from file."
        }
    }
}

class OtherDetailsEncoder {
    private let path: URL
    let fileHandle: FileHandle
    
    init(url: URL) throws {
        self.path = url
        try "".write(to: self.path, atomically: true, encoding: .utf8)
        self.fileHandle = try FileHandle(forWritingTo: self.path)
        guard let header = "timestamp, frame, deviceOrientation, originalWidth, originalHeight\n".data(using: .utf8) else {
            throw OtherDetailsCoderError.fileCreationFailed
        }
        try self.fileHandle.write(contentsOf: header)
    }
    
    func add(otherDetails: OtherDetailsData, frameNumber: UUID) throws {
        let frameNumber = String(frameNumber.uuidString)
        let deviceOrientationString: String = String(otherDetails.deviceOrientation.rawValue)
        let originalWidth = String(Float(otherDetails.originalSize.width))
        let originalHeight = String(Float(otherDetails.originalSize.height))
        
        let line = "\(otherDetails.timestamp), \(frameNumber), \(deviceOrientationString), \(originalWidth), \(originalHeight)\n"
        guard let lineData = line.data(using: .utf8) else {
            throw OtherDetailsCoderError.dataWriteFailed
        }
        try self.fileHandle.write(contentsOf: lineData)
    }
    
    func done() throws {
        try self.fileHandle.close()
    }
}

class OtherDetailsDecoder {
    private let path: URL
    let results: [OtherDetailsData]
    
    init(path: URL) throws {
        self.path = path
        self.results = try OtherDetailsDecoder.preload(path: path)
    }
    
    static func preload(path: URL) throws -> [OtherDetailsData] {
        guard FileManager.default.fileExists(atPath: path.absoluteString) else {
            throw OtherDetailsCoderError.fileNotFound
        }
        guard let fileContents = try? String(contentsOf: path, encoding: .utf8) else {
            throw OtherDetailsCoderError.fileReadFailed
        }
        let fileLines = fileContents.components(separatedBy: .newlines).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let expectedHeader = "timestamp, frame, deviceOrientation, originalWidth, originalHeight"
        guard let headerLine = fileLines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              headerLine == expectedHeader else {
            throw OtherDetailsCoderError.fileReadFailed
        }
        let columnNames = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let timestampIndex = columnNames.firstIndex(of: "timestamp")
        let frameIndex = columnNames.firstIndex(of: "frame")
        let deviceOrientationIndex = columnNames.firstIndex(of: "deviceOrientation")
        let originalWidthIndex = columnNames.firstIndex(of: "originalWidth")
        let originalHeightIndex = columnNames.firstIndex(of: "originalHeight")
        guard let timestampIndex, let frameIndex, let deviceOrientationIndex, let originalWidthIndex, let originalHeightIndex else {
            throw OtherDetailsCoderError.fileReadFailed
        }
        let maxIndex = max(timestampIndex, frameIndex, deviceOrientationIndex, originalWidthIndex, originalHeightIndex)
        var otherDetailsDataList: [OtherDetailsData] = []
        for line in fileLines.dropFirst() {
            let values = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard columnNames.count > maxIndex else {
                continue
            }
            guard let timestamp = TimeInterval(values[timestampIndex]),
                  let frameNumber = UUID(uuidString: values[frameIndex]),
                  let deviceOrientationRawValue = Int(values[deviceOrientationIndex]),
                  let deviceOrientation = UIInterfaceOrientation(rawValue: deviceOrientationRawValue),
                  let originalWidth = Float(values[originalWidthIndex]),
                  let originalHeight = Float(values[originalHeightIndex]) else {
                continue
            }
            let otherDetailsData = OtherDetailsData(
                timestamp: timestamp,
                deviceOrientation: deviceOrientation,
                originalSize: CGSize(width: CGFloat(originalWidth), height: CGFloat(originalHeight))
            )
            otherDetailsDataList.append(otherDetailsData)
        }
        return otherDetailsDataList
    }
}
