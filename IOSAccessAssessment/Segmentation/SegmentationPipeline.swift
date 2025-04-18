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
        let segmentationRequest = createSegmentationRequest()
        self.requests = [segmentationRequest]
    }
    
    private func createSegmentationRequest() -> VNCoreMLRequest {
        // TODO: Need to check on the ideal options for this
        let segmentationRequest = VNCoreMLRequest(model: self.visionModel) { [weak self] request, error in
            guard let self = self else { return }
            if let results = request.results as? [VNCoreMLFeatureValueObservation] {
                self.processSegmentationRequestOutput(results.first!)
            }
        }
        segmentationRequest.imageCropAndScaleOption = .scaleFill
        return segmentationRequest
    }
        
    private func processSegmentationRequestOutput(_ output: VNCoreMLFeatureValueObservation) {
        guard let segmentationBuffer = output.featureValue.imageBufferValue else { return }
        let segmentationImage = CIImage(cvPixelBuffer: segmentationBuffer)
        DispatchQueue.main.async {
            self.result = segmentationImage
        }
    }
    
    func processRequest(with cIImage: CIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.requestHandler.perform(self.requests, on: cIImage)
            } catch {
                print("Error performing request: \(error)")
            }
        }
    }
}
