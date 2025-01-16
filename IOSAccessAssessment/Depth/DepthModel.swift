//
//  DepthModel.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/15/25.
//
import SwiftUI
import Vision
import CoreML
import CoreImage
import os

enum DepthError: Error, LocalizedError {
    case emptyDepth
    case invalidDepth
    
    var errorDescription: String? {
        switch self {
        case .emptyDepth:
            return "The Depth array is Empty"
        case .invalidDepth:
            return "The Depth Estimation is invalid"
        }
    }
}

struct DepthResultsOutput {
    var depthResults: CIImage
    
    init(depthResults: CIImage) {
        self.depthResults = depthResults
    }
}

class DepthModel: ObservableObject {
    /// The last image supplied to DepthModel
    var lastImage = OSAllocatedUnfairLock<CIImage?>(uncheckedState: nil)
    
    /// The depth model
    var visionModel: MLModel?
    
    /// The resulting depth image
    @Published var depthResults: CIImage?
    
    init() {
        let modelURL = Bundle.main.url(forResource: "DepthAnythingV2SmallF16P6", withExtension: "mlmodelc")
//        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
//            fatalError("Cannot load CNN model")
//        }
        guard let visionModel = try? MLModel(contentsOf: modelURL!) else {
            fatalError("Cannot load Depth model")
        }
        self.visionModel = visionModel
    }
}
