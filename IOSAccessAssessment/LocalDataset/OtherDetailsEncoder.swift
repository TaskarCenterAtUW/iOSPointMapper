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

class OtherDetailsEncoder {
    private let path: URL
    let fileHandle: FileHandle
    
    init(url: URL) throws {
        self.path = url
        try "".write(to: self.path, atomically: true, encoding: .utf8)
        self.fileHandle = try FileHandle(forWritingTo: self.path)
        self.fileHandle.write("timestamp, frame, deviceOrientation, originalWidth, originalHeight\n".data(using: .utf8)!)
    }
    
    func add(otherDetails: OtherDetailsData, frameNumber: UUID) {
        let frameNumber = String(frameNumber.uuidString)
        let deviceOrientationString: String = String(otherDetails.deviceOrientation.rawValue)
        let originalWidth = String(Float(otherDetails.originalSize.width))
        let originalHeight = String(Float(otherDetails.originalSize.height))
        
        let line = "\(otherDetails.timestamp), \(frameNumber), \(deviceOrientationString), \(originalWidth), \(originalHeight)\n"
        self.fileHandle.write(line.data(using: .utf8)!)
    }
    
    func done() throws {
        try self.fileHandle.close()
    }
}
