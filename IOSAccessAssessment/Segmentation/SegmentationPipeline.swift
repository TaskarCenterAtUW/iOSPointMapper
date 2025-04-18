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
    var perimeterThreshold: Int = 200
    
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
                if contour.pointCount < self.perimeterThreshold {continue}
                try objectList.append(contour.polygonApproximation(epsilon: 0.5))
            }
            return objectList
        } catch {
            print("Error processing contour detection request: \(error)")
            return nil
        }
    }
    
    private func computeCentroid(for contour: VNContour) -> CGPoint {
        let points = contour.normalizedPoints
        guard !points.isEmpty else { return .zero }
        
        var sum: simd_float2 = .zero
        for point in points {
            sum.x += point.x
            sum.y += point.y
        }
        var count: Float = Float(points.count)
        
        return CGPoint(x: CGFloat(sum.x / count), y: CGFloat(sum.y / count))
    }
    
    private func computeBoundingBox(for contour: VNContour) -> CGRect {
        let points = contour.normalizedPoints
        guard !points.isEmpty else { return .zero }
        
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        
        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }
        
        return CGRect(x: CGFloat(minX), y: CGFloat(minY),
                        width: CGFloat(maxX - minX), height: CGFloat(maxY - minY))
    }
    
    private func computePerimeter(for contour: VNContour) -> Float {
        let points = contour.normalizedPoints
        guard points.count > 1 else { return 0 }
        
        var perimeter: Float = 0.0
        
        for i in 0..<(points.count - 1) {
            let dx = points[i+1].x - points[i].x
            let dy = points[i+1].y - points[i].y
            perimeter += sqrt(dx*dx + dy*dy)
        }
        
        // If contour is closed, add distance between last and first
        let dx = points.first!.x - points.last!.x
        let dy = points.first!.y - points.last!.y
        perimeter += sqrt(dx*dx + dy*dy)

        return perimeter
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
