//
//  TransformEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation
import Accelerate
import ARKit

class CameraTransformEncoder {
    enum Status {
        case ok
        case fileCreationError
    }
    private let path: URL
    let fileHandle: FileHandle
    public var status: Status = Status.ok
    
    init(url: URL) {
        self.path = url
        do {
            try "".write(to: self.path, atomically: true, encoding: .utf8)
            self.fileHandle = try FileHandle(forWritingTo: self.path)
            self.fileHandle.write("timestamp, frame, rxx, rxy, rxz, ryx, ryy, ryz, rzx, rzy, rzz, x, y, z\n".data(using: .utf8)!)
        } catch let error {
            print("Can't create file \(self.path.absoluteString). \(error.localizedDescription)")
            preconditionFailure("Can't open camera transform file for writing.")
        }
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
    
    func done() {
        do {
            try self.fileHandle.close()
        } catch let error {
            print("Can't close camera transform file \(self.path.absoluteString). \(error.localizedDescription)")
        }
    }
}
