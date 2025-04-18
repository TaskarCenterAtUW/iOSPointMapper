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
    
    // MARK: Temporary segmentationRequest UIImage
    @Published var segmentationResultUIImage: UIImage?
    
    private var detectContourRequests: [VNDetectContoursRequest] = [VNDetectContoursRequest]()
    @Published var objects: [VNContour] = []
    var pointCountThreshold: Int = 200
    
//    let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    let binaryMaskProcessor = BinaryMaskProcessor()
    
    init() {
        let modelURL = Bundle.main.url(forResource: "bisenetv2", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Cannot load CNN model")
        }
        self.visionModel = visionModel
        let segmentationRequest = VNCoreMLRequest(model: self.visionModel);
        configureSegmentationRequest(request: segmentationRequest)
        self.segmentationRequests = [segmentationRequest]
        
        let contourRequest = VNDetectContoursRequest()
        configureContourRequest(request: contourRequest)
        self.detectContourRequests = [contourRequest]
    }
    
    func processRequest(with cIImage: CIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.processSegmentationRequest(with: cIImage)
        }
    }
    
    private func configureSegmentationRequest(request: VNCoreMLRequest) {
        // TODO: Need to check on the ideal options for this
        request.imageCropAndScaleOption = .scaleFill
    }
    
    // MARK: Currently we are relying on the synchronous nature of the request handler
    // Need to check if this is always guaranteed.
    func processSegmentationRequest(with cIImage: CIImage) {
        do {
            try self.requestHandler.perform(self.segmentationRequests, on: cIImage)
            guard let segmentationResult = self.segmentationRequests.first?.results as? [VNPixelBufferObservation] else {return}
            let segmentationBuffer = segmentationResult.first?.pixelBuffer
            let segmentationImage = CIImage(cvPixelBuffer: segmentationBuffer!)
            DispatchQueue.main.async {
                self.segmentationResult = segmentationImage
                self.segmentationResultUIImage = UIImage(ciImage: segmentationImage, scale: 1.0, orientation: .downMirrored)
            }
            getObjects(from: segmentationImage)
        } catch {
            print("Error processing segmentation request: \(error)")
        }
    }
    
    private func configureContourRequest(request: VNDetectContoursRequest) {
        request.contrastAdjustment = 1.0
    }
    
    private func getContours(for image: CIImage) -> [VNContour]? {
        do {
            try self.requestHandler.perform(self.detectContourRequests, on: image)
            guard let contourResults = self.detectContourRequests.first?.results as? [VNContoursObservation] else {return nil}
            let contourResult = contourResults.first
            
            var objectList = [VNContour]()
            let contours = contourResult?.topLevelContours
            for contour in contours! {
                if contour.pointCount < self.pointCountThreshold {continue}
                try objectList.append(contour.polygonApproximation(epsilon: 0.5))
            }
            return objectList
        } catch {
            print("Error processing contour detection request: \(error)")
            return nil
        }
    }
    
    func getObjects(from segmentationImage: CIImage) {
        var objectList: [VNContour] = []
        let classes = Constants.ClassConstants.labels
        
        for className in classes {
            let mask = binaryMaskProcessor.apply(to: segmentationImage, targetValue: className)
            
            objectList.append(contentsOf: getContours(for: mask!) ?? [])
        }
        print("Number of objects detected: \(objectList.count)")
        
        DispatchQueue.main.async {
            self.objects = objectList
        }
    }
}
