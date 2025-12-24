//
//  TransformEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation

enum CameraTransformEncoderError: Error, LocalizedError {
    case unableToCreateFile
    case dataWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .unableToCreateFile:
            return "Unable to create camera transform file."
        case .dataWriteFailed:
            return "Failed to write data to camera transform file."
        }
    }
}

class CameraTransformEncoder {
    private let path: URL
    let fileHandle: FileHandle
    
    init(url: URL) throws {
        self.path = url
        try "".write(to: self.path, atomically: true, encoding: .utf8)
        self.fileHandle = try FileHandle(forWritingTo: self.path)
        guard let header = "timestamp, frame, rxx, rxy, rxz, ryx, ryy, ryz, rzx, rzy, rzz, x, y, z\n".data(using: .utf8) else {
            throw CameraTransformEncoderError.unableToCreateFile
        }
        self.fileHandle.write(header)
    }
    
    func add(transform: simd_float4x4, timestamp: TimeInterval, frameNumber: UUID) {
        let rotationX = transform.columns.0
        let rotationY = transform.columns.1
        let rotationZ = transform.columns.2
        let translation = transform.columns.3
        
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(timestamp), \(frameNumber), \(rotationX.x), \(rotationX.y), \(rotationX.z), \(rotationY.x), \(rotationY.y), \(rotationY.z), \(rotationZ.x), \(rotationZ.y), \(rotationZ.z), \(translation.x), \(translation.y), \(translation.z)\n"
        self.fileHandle.write(line.data(using: .utf8)!)
    }
    
    func done() throws {
        try self.fileHandle.close()
    }
}
