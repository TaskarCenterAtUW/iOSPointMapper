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

enum OtherDetailsEncoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create other details file."
        case .dataWriteFailed:
            return "Failed to write details data to file."
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
            throw OtherDetailsEncoderError.fileCreationFailed
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
            throw OtherDetailsEncoderError.dataWriteFailed
        }
        try self.fileHandle.write(contentsOf: lineData)
    }
    
    func done() throws {
        try self.fileHandle.close()
    }
}
