//
//  RGBEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation
import CoreImage
import UIKit

enum RGBEncoderError: Error, LocalizedError {
    case invalidImageData
    case writeFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The image data is invalid."
        case .writeFailed(let message):
            return "Failed to write image data: \(message)"
        }
    }
}

class RGBEncoder {
    private let baseDirectory: URL

    init(outDirectory: URL) throws {
        self.baseDirectory = outDirectory
        try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    func save(ciImage: CIImage, frameNumber: UUID) throws {
        let filename = String(frameNumber.uuidString)
        let image = UIImage(ciImage: ciImage)
        guard let data = image.pngData() else {
            throw RGBEncoderError.invalidImageData
        }
        let path = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
        try data.write(to: path)
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
