//
//  ConfidenceEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation
import CoreImage

enum ConfidenceEncoderError: Error, LocalizedError {
    case frameDataTypeMismatch
    
    var errorDescription: String? {
        switch self {
        case .frameDataTypeMismatch:
            return "The frame data type is not compatible with confidence encoding."
        }
    }
}

class ConfidenceEncoder {
    private let baseDirectory: URL
    private let ciContext: CIContext

    init(outDirectory: URL) throws {
        self.baseDirectory = outDirectory
        self.ciContext = CIContext()
        try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
    }

    func encodeFrame(frame: CVPixelBuffer, frameNumber: UUID) throws {
        let filename = String(frameNumber.uuidString)
        let image = CIImage(cvPixelBuffer: frame)
        guard (CVPixelBufferGetPixelFormatType(frame) == kCVPixelFormatType_OneComponent8) else {
            throw ConfidenceEncoderError.frameDataTypeMismatch
        }
        let framePath = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")

        if let colorSpace = CGColorSpace(name: CGColorSpace.extendedGray) {
            try self.ciContext.writePNGRepresentation(of: image, to: framePath, format: CIFormat.L8, colorSpace: colorSpace)
        }
    }
}
