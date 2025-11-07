//
//  SegmentationEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/7/25.
//

import Foundation
import CoreImage
import UIKit

class SegmentationEncoder {
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
}
