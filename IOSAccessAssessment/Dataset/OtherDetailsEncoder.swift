//
//  OtherDetailsEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/7/25.
//

import Foundation
import Accelerate
import ARKit

class OtherDetailsEncoder {
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
            self.fileHandle.write("timestamp, frame, deviceOrientation, originalWidth, originalHeight\n".data(using: .utf8)!)
        } catch let error {
            print("Can't create file \(self.path.absoluteString). \(error.localizedDescription)")
            preconditionFailure("Can't open camera transform file for writing.")
        }
    }
    
    func add(deviceOrientation: UIDeviceOrientation = .portrait, originalSize: CGSize, timestamp: TimeInterval, frameNumber: UUID) {
        let frameNumber = String(frameNumber.uuidString)
        let deviceOrientationString: String = String(deviceOrientation.rawValue)
        let originalWidth = String(Float(originalSize.width))
        let originalHeight = String(Float(originalSize.height))
        
        let line = "\(timestamp), \(frameNumber), \(deviceOrientationString), \(originalWidth), \(originalHeight)\n"
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
