//
//  ConfidenceEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation
import CoreImage

class ConfidenceEncoder {
    enum Status {
        case ok
        case fileCreationError
    }
    private let baseDirectory: URL
    private let ciContext: CIContext
    public var status: Status = Status.ok

    init(outDirectory: URL) {
        self.baseDirectory = outDirectory
        self.ciContext = CIContext()
        do {
            try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            print("Could not create confidence folder. \(error.localizedDescription)")
            status = Status.fileCreationError
        }
    }

    func encodeFrame(frame: CVPixelBuffer, frameNumber: UUID) {
        let filename = String(frameNumber.uuidString)
        let image = CIImage(cvPixelBuffer: frame)
        assert(CVPixelBufferGetPixelFormatType(frame) == kCVPixelFormatType_OneComponent8)
        let framePath = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("png")

        if let colorSpace = CGColorSpace(name: CGColorSpace.extendedGray) {
            do {
                try self.ciContext.writePNGRepresentation(of: image, to: framePath, format: CIFormat.L8, colorSpace: colorSpace)
            } catch let error {
                print("Could not save confidence value. \(error.localizedDescription)")
            }
        }
    }
}
