//
//  SegmentationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/17/25.
//

import SwiftUI
import Vision
import CoreML

struct DetectedObject {
    let classLabel: UInt8
    let centroid: CGPoint
    let boundingBox: CGRect
    let normalizedPoints: [simd_float2]
}

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
    @Published var objects: [DetectedObject] = []
    var contourEpsilon: Float = 0.5
    // TODO: Check what would be the appropriate value for this
    // For normalized points
    var perimeterThreshold: Float = 0.0001
    
    let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    let binaryMaskProcessor = BinaryMaskProcessor()
    
    init() {
        let modelURL = Bundle.main.url(forResource: "espnetv2_pascal_256", withExtension: "mlmodelc")
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
                
                // Temporary
                self.grayscaleToColorMasker.inputImage = segmentationImage
                self.grayscaleToColorMasker.grayscaleValues = Constants.ClassConstants.grayscaleValues
                self.grayscaleToColorMasker.colorValues =  Constants.ClassConstants.colors
                self.segmentationResultUIImage = UIImage(ciImage: self.grayscaleToColorMasker.outputImage!,
                                                         scale: 1.0, orientation: .leftMirrored)
            }
            getObjects(from: segmentationImage)
        } catch {
            print("Error processing segmentation request: \(error)")
        }
    }
    
    private func configureContourRequest(request: VNDetectContoursRequest) {
        request.contrastAdjustment = 1.0
    }
    
    private func getObjectsFromBinaryImage(for image: CIImage, classLabel: UInt8) -> [DetectedObject]? {
        do {
            try self.requestHandler.perform(self.detectContourRequests, on: image)
            guard let contourResults = self.detectContourRequests.first?.results as? [VNContoursObservation] else {return nil}
            
            let contourResult = contourResults.first
            
            var objectList = [DetectedObject]()
            let contours = contourResult?.topLevelContours
            for contour in contours! {
                let contourApproximation = try contour.polygonApproximation(epsilon: self.contourEpsilon)
                let contourDetails = getContourDetails(from: contourApproximation)
                if contourDetails.perimeter < self.perimeterThreshold {continue}
                
                objectList.append(DetectedObject(classLabel: classLabel,
                                                centroid: contourDetails.centroid,
                                                boundingBox: contourDetails.boundingBox,
                                                normalizedPoints: contourApproximation.normalizedPoints))
            }
            return objectList
        } catch {
            print("Error processing contour detection request: \(error)")
            return nil
        }
    }
    
    /**
     Function to compute the centroid, bounding box, and perimeter of a contour more efficiently
     */
    private func getContourDetails(from contour: VNContour) -> (centroid: CGPoint, boundingBox: CGRect, perimeter: Float) {
        let points = contour.normalizedPoints
        guard !points.isEmpty else { return (CGPoint.zero, .zero, 0) }
        
        let count: Float = Float(points.count)
        // For centroid
        var sum: simd_float2 = .zero
        // For bounding box
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        // For perimeter
        var perimeter: Float = 0.0
        
        for i in 0..<(points.count - 1) {
            // For centroid
            sum.x += points[i].x
            sum.y += points[i].y
            // For bounding box
            minX = min(minX, points[i].x)
            minY = min(minY, points[i].y)
            maxX = max(maxX, points[i].x)
            maxY = max(maxY, points[i].y)
            // For perimeter
            let dx = points[i+1].x - points[i].x
            let dy = points[i+1].y - points[i].y
            perimeter += sqrt(dx*dx + dy*dy)
        }
        
        // For centroid
        let centroid = CGPoint(x: CGFloat(sum.x / count), y: CGFloat(sum.y / count))
        // For bounding box
        let boundingBox = CGRect(x: CGFloat(minX), y: CGFloat(minY),
                                 width: CGFloat(maxX - minX), height: CGFloat(maxY - minY))
        // If contour is closed, add distance between last and first
        let dx = points.first!.x - points.last!.x
        let dy = points.first!.y - points.last!.y
        perimeter += sqrt(dx*dx + dy*dy)
        
        return (centroid, boundingBox, perimeter)
    }
    
    func getObjects(from segmentationImage: CIImage) {
        var objectList: [DetectedObject] = []
        let classes = Constants.ClassConstants.labels//[0...2]
        
        for classLabel in classes {
            let mask = binaryMaskProcessor.apply(to: segmentationImage, targetValue: classLabel)
            let objects = getObjectsFromBinaryImage(for: mask!, classLabel: classLabel)
            objectList.append(contentsOf: objects ?? [])
        }
        
        DispatchQueue.main.async {
            self.objects = objectList
        }
    }
}
