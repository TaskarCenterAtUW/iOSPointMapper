//
//  SegmentationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/17/25.
//

import SwiftUI
import Vision
import CoreML

/**
    A class to handle segmentation as well as the post-processing of the segmentation results on demand.
 */
class SegmentationPipeline: ObservableObject {
    var visionModel: VNCoreMLModel
    private(set) var requests: [VNRequest] = [VNRequest]()
    private let requestHandler = VNSequenceRequestHandler()
    
    @Published var result: CIImage?
    @Published var classIndices: [Int] = []
    
    let masker = GrayscaleToColorCIFilter()
    
    init() {
        let modelURL = Bundle.main.url(forResource: "bisenetv2", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Cannot load CNN model")
        }
        self.visionModel = visionModel
        let segmentationRequest = VNCoreMLRequest(model: self.visionModel);
        configureSegmentationRequest(request: segmentationRequest)
        self.requests = [VNCoreMLRequest(model: self.visionModel)]
    }
    
    private func configureSegmentationRequest(request: VNCoreMLRequest) {
        // TODO: Need to check on the ideal options for this
        request.imageCropAndScaleOption = .scaleFill
    }
    
    func processRequest(with cIImage: CIImage) {
        
    }
}
