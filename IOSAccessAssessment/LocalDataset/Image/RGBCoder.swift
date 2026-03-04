//
//  RGBEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation
import CoreImage
import UIKit

enum RGBCoderError: Error, LocalizedError {
    case invalidImageData
    case writeFailed(String)
    case invalidFilePath(String)
    case invalidFileData
    case pixelBufferCreationFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "The image data is invalid."
        case .writeFailed(let message):
            return "Failed to write image data: \(message)"
        case .invalidFilePath(let path):
            return "The file path is invalid: \(path)"
        case .invalidFileData:
            return "The file data is invalid."
        case .pixelBufferCreationFailed(let status):
            return "Failed to create pixel buffer. OSStatus: \(status)"
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
            throw RGBCoderError.invalidImageData
        }
        let path = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
        try data.write(to: path)
    }
}

class RGBDecoder {
    private let baseDirectory: URL
    
    init(inDirectory: URL) {
        self.baseDirectory = inDirectory
    }
    
    func load(frameNumber: UUID) throws -> CVPixelBuffer {
        let filename = String(frameNumber.uuidString)
        let path = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw RGBCoderError.invalidFilePath(path.path)
        }
        guard let data = try? Data(contentsOf: path) else {
            throw RGBCoderError.invalidFileData
        }
        guard let image = UIImage(data: data),
              let cgImage = image.cgImage else {
            throw RGBCoderError.invalidFileData
        }
        let width = cgImage.width
        let height = cgImage.height
        
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw RGBCoderError.pixelBufferCreationFailed(status)
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: bitmapInfo) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            throw RGBCoderError.pixelBufferCreationFailed(-1)
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
    
    func load(frameNumber: UUID) throws -> CIImage {
        let pixelBuffer: CVPixelBuffer = try load(frameNumber: frameNumber)
        return CIImage(cvPixelBuffer: pixelBuffer)
    }
}
