//
//  CameraIntrinsicsEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/23/25.
//

import Foundation

enum CameraIntrinsicsEncoderError: Error, LocalizedError {
    case unableToCreateFile
    
    var errorDescription: String? {
        switch self {
        case .unableToCreateFile:
            return "Unable to create camera intrinsics file."
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
        guard let header = "timestamp, frame, fx, sx, cx, sy, fy, cy, i20, i21, i22\n".data(using: .utf8) else {
            throw CameraIntrinsicsEncoderError.unableToCreateFile
        }
        self.fileHandle.write(header)
    }
    
    func add(intrinsics: simd_float3x3, timestamp: TimeInterval, frameNumber: UUID) {
        let fx = intrinsics[0,0]
        let sx = intrinsics[0,1]
        let cx = intrinsics[0,2]
        let sy = intrinsics[1,0]
        let fy = intrinsics[1,1]
        let cy = intrinsics[1,2]
        let i20 = intrinsics[2,0]
        let i21 = intrinsics[2,1]
        let i22 = intrinsics[2,2]
        
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(timestamp), \(frameNumber), \(fx), \(sx), \(cx), \(sy), \(fy), \(cy), \(i20), \(i21), \(i22)\n"
        self.fileHandle.write(line.data(using: .utf8)!)
    }
    
    func done() throws {
        try self.fileHandle.close()
    }
}
