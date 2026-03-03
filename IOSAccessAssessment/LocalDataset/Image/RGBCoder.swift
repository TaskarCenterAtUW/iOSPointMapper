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
    
    func load(frameNumber: UUID) throws -> CIImage {
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
        return CIImage(cgImage: cgImage)
    }
}
