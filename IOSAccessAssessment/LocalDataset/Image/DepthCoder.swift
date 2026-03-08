//
//  DepthEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation
import CoreImage
import UIKit

enum DepthCoderError: Error, LocalizedError {
    case invalidImageData
    case writeFailed(String)
    case invalidFileData
    case fileReadFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The image data is invalid."
        case .writeFailed(let message):
            return "Failed to write image data: \(message)"
        case .invalidFileData:
            return "The file data is invalid."
        case .fileReadFailed:
            return "Failed to read the file data."
        }
    }
}

class DepthEncoder {
    private let baseDirectory: URL

    init(outDirectory: URL) throws {
        self.baseDirectory = outDirectory
        try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
    }

    /// TODO: Replace this logic with a function that uses PngEncoder
//    func save(ciImage: CIImage, frameNumber: UUID) throws {
//        let filename = String(frameNumber.uuidString)
//        let image = UIImage(ciImage: ciImage)
//        guard let data = image.pngData() else {
//            throw DepthEncoderError.invalidImageData
//        }
//        let path = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
//        try data.write(to: path)
//    }
    
    func encodeFrame(frame: CVPixelBuffer, frameNumber: UUID) throws {
        let filename = String(frameNumber.uuidString)
        let encoder = try self.convert(frame: frame)
        guard let data = encoder.fileContents() else {
            throw DepthCoderError.invalidImageData
        }
        let framePath = self.baseDirectory.absoluteURL.appendingPathComponent(
            filename, isDirectory: false
        ).appendingPathExtension("png")
        try data.write(to: framePath)
    }
    
    private func convert(frame: CVPixelBuffer) throws -> PngEncoder {
        guard CVPixelBufferGetPixelFormatType(frame) == kCVPixelFormatType_DepthFloat32 else {
            throw DepthCoderError.invalidImageData
        }
        let height = CVPixelBufferGetHeight(frame)
        let width = CVPixelBufferGetWidth(frame)
        CVPixelBufferLockBaseAddress(frame, CVPixelBufferLockFlags.readOnly)
        guard let inBase = CVPixelBufferGetBaseAddress(frame) else {
            throw DepthCoderError.invalidImageData
        }
        let inPixelData = inBase.assumingMemoryBound(to: Float32.self)
        guard let out = PngEncoder.init(depth: inPixelData, width: Int32(width), height: Int32(height)) else {
            throw DepthCoderError.invalidImageData
        }
        CVPixelBufferUnlockBaseAddress(frame, CVPixelBufferLockFlags(rawValue: 0))
        return out
    }
}

class DepthDecoder {
    private let baseDirectory: URL
    
    init(inDirectory: URL) {
        self.baseDirectory = inDirectory
    }
    
    func decodeFrame(frameNumber: UUID) throws -> CVPixelBuffer {
        let filename = String(frameNumber.uuidString)
        let framePath = self.baseDirectory.absoluteURL.appendingPathComponent(
            filename, isDirectory: false
        ).appendingPathExtension("png")
        let data = try Data(contentsOf: framePath)
        
        let decoder = PngDecoder(contentsOfFile: data)
        var width: Int32 = 0
        var height: Int32 = 0
        
        guard let depthData: Data = decoder.depthData(withWidth: &width, height: &height) else {
            throw DepthCoderError.invalidFileData
        }
        
        let pixelCount = Int(width * height)
        var pixelBuffer: CVPixelBuffer?
        
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_DepthFloat32,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height), kCVPixelFormatType_DepthFloat32, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw DepthCoderError.fileReadFailed
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let bufferBaseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw DepthCoderError.fileReadFailed
        }
        try depthData.withUnsafeBytes { depthPtr in
            guard let depthBaseAddress = depthPtr.baseAddress else {
                throw DepthCoderError.invalidFileData
            }
            bufferBaseAddress.copyMemory(from: depthBaseAddress, byteCount: pixelCount * MemoryLayout<Float32>.size)
        }
        
//        CVPixelBufferUnlockBaseAddress(buffer, [])
//        /// Read a few pixels to verify the data was copied correctly
//        CVPixelBufferLockBaseAddress(buffer, .readOnly)
//        if let verifyBaseAddress = CVPixelBufferGetBaseAddress(buffer) {
//            let verifyPixelData = verifyBaseAddress.assumingMemoryBound(to: Float32.self)
//            print("First 5 values: \(Array(UnsafeBufferPointer(start: verifyPixelData, count: min(5, pixelCount))))")
//        }
        
        return buffer
    }
}
