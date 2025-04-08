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

/**
 A class to handle depth estimation on demand.
 
 Currently, it performs the depth estimation process synchronously. This is not recommended for real-time applications.
 */
class DepthModel: ObservableObject {
    let context = CIContext()
    /// A pixel buffer used as input to the model.
    let inputPixelBuffer: CVPixelBuffer
    
    /// The depth model
    var visionModel: DepthAnythingV2SmallF16?
    
    /// The resulting depth image
//    @Published var depthResults: CIImage?
    
    init() {
        // Create a reusable buffer to avoid allocating memory for every model invocation
        var buffer: CVPixelBuffer!
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(Constants.DepthConstants.inputSize.width),
            Int(Constants.DepthConstants.inputSize.height),
            kCVPixelFormatType_32ARGB,
            nil,
            &buffer
        )
        guard status == kCVReturnSuccess else {
            fatalError("Failed to create pixel buffer")
        }
        inputPixelBuffer = buffer
        
        do {
            try loadModel()
        } catch {
            print("Failed to load model: \(error.localizedDescription)")
        }
    }
    
    func loadModel() throws {
        print("Loading depth model...")
//        visionModel = try DepthAnythingV2SmallF16()
    }
    
    /**
     Perform depth estimation on the given image. This is done synchronously.
     
     - Parameter ciImage: The image for which to perform depth estimation.
     */
    func performDepthEstimation(_ ciImage: CIImage) -> CIImage {
        let originalSize: CGSize = ciImage.extent.size
        guard let visionModel else {
            return CIImage(cvPixelBuffer: createBlankDepthPixelBuffer(targetSize: originalSize)!)
        }
        
        let inputImage = ciImage.resized(to: Constants.DepthConstants.inputSize)
        context.render(inputImage, to: inputPixelBuffer)
        guard let result = try? visionModel.prediction(image: inputPixelBuffer) else {
            return CIImage(cvPixelBuffer: createBlankDepthPixelBuffer(targetSize: originalSize)!)
        }
        let outputImage: CIImage = CIImage(cvPixelBuffer: result.depth)
            .resized(to: originalSize)
//        self.depthResults = outputImage
        return outputImage
    }
    
    
}
