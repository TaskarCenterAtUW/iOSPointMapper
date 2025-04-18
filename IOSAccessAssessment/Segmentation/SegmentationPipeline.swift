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
    private(set) var segmentationRequests: [VNCoreMLRequest] = [VNCoreMLRequest]()
    private let requestHandler = VNSequenceRequestHandler()
    @Published var segmentationResult: CIImage?
    @Published var segmentedIndices: [Int] = []
    
    private var detectContourRequests: [VNDetectContoursRequest] = [VNDetectContoursRequest]()
    @Published var objects: [CGRect] = []
    
    let masker = GrayscaleToColorCIFilter()
    
    init() {
        let modelURL = Bundle.main.url(forResource: "bisenetv2", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Cannot load CNN model")
        }
        self.visionModel = visionModel
        let segmentationRequest = VNCoreMLRequest(model: self.visionModel);
        configureSegmentationRequest(request: segmentationRequest)
        self.segmentationRequests = [segmentationRequest]
        
        self.detectContourRequests = [VNDetectContoursRequest()]
    }
    
    private func configureSegmentationRequest(request: VNCoreMLRequest) {
        // TODO: Need to check on the ideal options for this
        request.imageCropAndScaleOption = .scaleFill
    }
    
    // MARK: Currently we are relying on the synchronous nature of the request handler
    // Need to check if this is always guaranteed.
    func processRequest(with cIImage: CIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.requestHandler.perform(self.segmentationRequests, on: cIImage)
                if let segmentationResult = self.segmentationRequests.first?.results as? [VNPixelBufferObservation] {
                    let segmentationBuffer = segmentationResult.first?.pixelBuffer
                    let segmentationImage = CIImage(cvPixelBuffer: segmentationBuffer!)
                    DispatchQueue.main.async {
                        self.segmentationResult = segmentationImage
                    }
                }
            } catch {
                print("Error processing request: \(error)")
            }
        }
    }
    
    private func getContours(for image: CIImage) {
    }
    
    func getObjects(from segmentationImage: CIImage) {
    }
    
    
}
