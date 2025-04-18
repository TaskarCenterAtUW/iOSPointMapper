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
    @Published var segmentationResult: CIImage?
    @Published var segmentedIndices: [Int] = []
    var selectionClassLabels: [UInt8] = []
    
    // MARK: Temporary segmentationRequest UIImage
    @Published var segmentationResultUIImage: UIImage?
    
    // MARK: Due to parallel processing, we need to create a separate request for each thread
//    private var detectContourRequests: [VNDetectContoursRequest] = [VNDetectContoursRequest]()
    @Published var objects: [DetectedObject] = []
    // TODO: Check what would be the appropriate value for this
    var contourEpsilon: Float = 0.01
    // TODO: Check what would be the appropriate value for this
    // For normalized points
    var perimeterThreshold: Float = 0.01
    
    // TODO: GrayscaleToColorCIFilter will not be restricted to only the selected classes because we are using the ClassConstants
    let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    let binaryMaskProcessor = BinaryMaskProcessor()
    
    var avgContourTime: Float = 0.0
    var avgContourCount = 0
    
    init() {
        let modelURL = Bundle.main.url(forResource: "espnetv2_pascal_256", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Cannot load CNN model")
        }
        self.visionModel = visionModel
        let segmentationRequest = VNCoreMLRequest(model: self.visionModel);
        configureSegmentationRequest(request: segmentationRequest)
        self.segmentationRequests = [segmentationRequest]
        
//        let contourRequest = VNDetectContoursRequest()
//        configureContourRequest(request: contourRequest)
//        self.detectContourRequests = [contourRequest]
    }
    
    func setSelectionClassLabels(_ classLabels: [UInt8]) {
        self.selectionClassLabels = classLabels
    }
    
    func processRequest(with cIImage: CIImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            let segmentationImage = self.processSegmentationRequest(with: cIImage)
            let objectList = self.getObjects(from: segmentationImage!)
            DispatchQueue.main.async {
                self.segmentationResult = segmentationImage
                self.objects = objectList ?? []
                
                // Temporary
//                self.grayscaleToColorMasker.inputImage = segmentationImage
//                self.grayscaleToColorMasker.grayscaleValues = Constants.ClassConstants.grayscaleValues
//                self.grayscaleToColorMasker.colorValues =  Constants.ClassConstants.colors
//                self.segmentationResultUIImage = UIImage(ciImage: self.grayscaleToColorMasker.outputImage!,
//                                                         scale: 1.0, orientation: .downMirrored)
                
                // Temporary
                self.segmentationResultUIImage = UIImage(
                    ciImage: rasterizeContourObjects(objects: objectList!, size: Constants.ClassConstants.inputSize)!,
                    scale: 1.0, orientation: .leftMirrored)
            }
        }
    }
    
    private func configureSegmentationRequest(request: VNCoreMLRequest) {
        // TODO: Need to check on the ideal options for this
        request.imageCropAndScaleOption = .scaleFill
    }
    
    // MARK: Currently we are relying on the synchronous nature of the request handler
    // Need to check if this is always guaranteed.
    func processSegmentationRequest(with cIImage: CIImage) -> CIImage? {
        do {
            // TODO: Check if this is the correct orientation, based on which the UIImage orientation will also be set
            let segmentationRequestHandler = VNImageRequestHandler(ciImage: cIImage, orientation: .right, options: [:])
            try segmentationRequestHandler.perform(self.segmentationRequests)
            guard let segmentationResult = self.segmentationRequests.first?.results as? [VNPixelBufferObservation] else {return nil}
            let segmentationBuffer = segmentationResult.first?.pixelBuffer
            let segmentationImage = CIImage(cvPixelBuffer: segmentationBuffer!)
            return segmentationImage
        } catch {
            print("Error processing segmentation request: \(error)")
        }
        return nil
    }
    
    private func configureContourRequest(request: VNDetectContoursRequest) {
        request.contrastAdjustment = 1.0
//        request.maximumImageDimension = 256
    }
    
    /**
        Function to rasterize the detected objects on the image. Creates a unique request and handler since it is run on a separate thread
    */
    private func getObjectsFromBinaryImage(for binaryImage: CIImage, classLabel: UInt8) -> [DetectedObject]? {
        do {
            let contourRequest = VNDetectContoursRequest()
            self.configureContourRequest(request: contourRequest)
            let contourRequestHandler = VNImageRequestHandler(ciImage: binaryImage, orientation: .right, options: [:])
            try contourRequestHandler.perform([contourRequest])
            guard let contourResults = contourRequest.results else {return nil}
            
            let contourResult = contourResults.first
            
            var objectList = [DetectedObject]()
            let contours = contourResult?.topLevelContours
            for contour in contours! {
                let contourApproximation = try contour.polygonApproximation(epsilon: self.contourEpsilon)
                let contourDetails = self.getContourDetails(from: contourApproximation)
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
    
    /**
        Function to get the detected objects from the segmentation image.
            Processes each class in parallel to get the objects.
     */
    func getObjects(from segmentationImage: CIImage) -> [DetectedObject]? {
        var objectList: [DetectedObject] = []
        let lock = NSLock()
        
        let start = DispatchTime.now()
        DispatchQueue.concurrentPerform(iterations: self.selectionClassLabels.count) { index in
            let classLabel = self.selectionClassLabels[index]
            let mask = self.binaryMaskProcessor.apply(to: segmentationImage, targetValue: classLabel)
            let objects = self.getObjectsFromBinaryImage(for: mask!, classLabel: classLabel)
            
            lock.lock()
            objectList.append(contentsOf: objects ?? [])
            lock.unlock()
        }
        let end = DispatchTime.now()
        let timeInterval = (end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        print("Contour detection time: \(timeInterval) ms")
        
        return objectList
    }
}
