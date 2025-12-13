//
//  SegmentationEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/7/25.
//

import Foundation
import CoreImage
import UIKit

enum SegmentationEncoderError: Error, LocalizedError {
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

class SegmentationEncoder {
    private let baseDirectory: URL
    
    init(outDirectory: URL) throws {
        self.baseDirectory = outDirectory
        try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    func save(ciImage: CIImage, frameNumber: UUID) throws {
        let filename = String(frameNumber.uuidString)
        let image = UIImage(ciImage: ciImage)
        guard let data = image.pngData() else {
            throw SegmentationEncoderError.invalidImageData
        }
        let path = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")
        try data.write(to: path)
    }
}
