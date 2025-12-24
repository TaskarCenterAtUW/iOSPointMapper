//
//  CameraIntrinsicsEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/23/25.
//

import Foundation

enum CameraIntrinsicsEncoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create camera intrinsics file."
        case .dataWriteFailed:
            return "Failed to write data to camera intrinsics file."
        }
    }
}

class CameraIntrinsicsEncoder {
    private let path: URL
    let fileHandle: FileHandle
    
    init(url: URL) throws {
        self.path = url
        try "".write(to: self.path, atomically: true, encoding: .utf8)
        self.fileHandle = try FileHandle(forWritingTo: self.path)
        guard let header = "timestamp, frame, fx, sx, cx, sy, fy, cy, i02, i12, i22\n".data(using: .utf8) else {
            throw CameraIntrinsicsEncoderError.fileCreationFailed
        }
        try self.fileHandle.write(contentsOf: header)
    }
    
    func add(intrinsics: simd_float3x3, timestamp: TimeInterval, frameNumber: UUID) throws {
        let fx = intrinsics[0,0]
        let sx = intrinsics[1,0]
        let cx = intrinsics[2,0]
        let sy = intrinsics[0,1]
        let fy = intrinsics[1,1]
        let cy = intrinsics[2,1]
        let i02 = intrinsics[0,2]
        let i12 = intrinsics[1,2]
        let i22 = intrinsics[2,2]
        
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(timestamp), \(frameNumber), \(fx), \(sx), \(cx), \(sy), \(fy), \(cy), \(i02), \(i12), \(i22)\n"
        guard let lineData = line.data(using: .utf8) else {
            throw CameraIntrinsicsEncoderError.dataWriteFailed
        }
        try self.fileHandle.write(contentsOf: lineData)
    }
    
    func done() throws {
        try self.fileHandle.close()
    }
}
