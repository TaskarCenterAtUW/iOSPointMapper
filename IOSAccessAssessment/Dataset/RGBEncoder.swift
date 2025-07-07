//
//  RGBEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation
import CoreImage
import UIKit

class RGBEncoder {
    enum Status {
        case ok
        case fileCreationError
    }
    private let baseDirectory: URL
    public var status: Status = Status.ok

    init(outDirectory: URL) {
        self.baseDirectory = outDirectory
        do {
            try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            print("Could not create folder. \(error.localizedDescription)")
            status = Status.fileCreationError
        }
    }

    func save(ciImage: CIImage, frameNumber: UUID) {
        let filename = String(frameNumber.uuidString)
        let image = UIImage(ciImage: ciImage)
        guard let data = image.pngData() else {
            print("Could not convert CIImage to PNG data for frame \(frameNumber).")
            return
        }
        let path = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
        do {
            try data.write(to: path)
        } catch let error {
            print("Could not save depth image \(frameNumber). \(error.localizedDescription)")
        }
    }
    
//    private func convert(frame: CVPixelBuffer) -> PngEncoder {
//        assert(CVPixelBufferGetPixelFormatType(frame) == kCVPixelFormatType_DepthFloat32)
//        let height = CVPixelBufferGetHeight(frame)
//        let width = CVPixelBufferGetWidth(frame)
//        CVPixelBufferLockBaseAddress(frame, CVPixelBufferLockFlags.readOnly)
//        let inBase = CVPixelBufferGetBaseAddress(frame)
//        let inPixelData = inBase!.assumingMemoryBound(to: Float32.self)
//
//        let out = PngEncoder.init(depth: inPixelData, width: Int32(width), height: Int32(height))!
//        CVPixelBufferUnlockBaseAddress(frame, CVPixelBufferLockFlags(rawValue: 0))
//        return out
//    }
}
