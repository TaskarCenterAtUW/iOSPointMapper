//
//  ContourRequestProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/5/25.
//
import Vision

/**
    ContourRequestProcessor is a struct that processes contour detection requests using Vision framework.
    It performs the contour detection concurrently for each class label in the segmentation image.
 */
struct ContourRequestProcessor {
    var contourEpsilon: Float = 0.01
    // For normalized points
    var perimeterThreshold: Float = 0.01
    var selectionClassLabels: [UInt8] = []
    
    let binaryMaskFilter = BinaryMaskFilter()
    
    init(contourEpsilon: Float = 0.01,
                perimeterThreshold: Float = 0.01,
              selectionClassLabels: [UInt8] = []) {
        self.contourEpsilon = contourEpsilon
        self.perimeterThreshold = perimeterThreshold
        self.selectionClassLabels = selectionClassLabels
    }
    
    mutating func setSelectionClassLabels(_ selectionClassLabels: [UInt8]) {
        self.selectionClassLabels = selectionClassLabels
    }
    
    private func configureContourRequest(request: VNDetectContoursRequest) {
        request.contrastAdjustment = 1.0
//        request.maximumImageDimension = 256
    }
    
    /**
        Function to rasterize the detected objects on the image. Creates a unique request and handler since it is run on a separate thread
    */
    func getObjectsFromBinaryImage(for binaryImage: CIImage, classLabel: UInt8,
                                           orientation: CGImagePropertyOrientation = .up) -> [DetectedObject]? {
        do {
            let contourRequest = VNDetectContoursRequest()
            self.configureContourRequest(request: contourRequest)
            let contourRequestHandler = VNImageRequestHandler(ciImage: binaryImage, orientation: orientation, options: [:])
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
                                                normalizedPoints: contourApproximation.normalizedPoints,
                                                perimeter: contourDetails.perimeter,
                                                isCurrent: true))
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
    // TODO: Check if the performance can be improved by using SIMD operations
    private func getContourDetails(from contour: VNContour) -> (centroid: CGPoint, boundingBox: CGRect, perimeter: Float) {
        let points = contour.normalizedPoints
        guard !points.isEmpty else { return (CGPoint.zero, .zero, 0) }
        
        let count: Float = Float(points.count)
        // For centroid
        var sum: SIMD2<Float> = .zero
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
    // TODO: Using DispatchQueue.concurrentPerform for parallel processing may not be the best approach for CPU-bound tasks.
    func processRequest(from segmentationImage: CIImage, orientation: CGImagePropertyOrientation = .up) -> [DetectedObject]? {
        var objectList: [DetectedObject] = []
        let lock = NSLock()
//        let start = DispatchTime.now()
        DispatchQueue.concurrentPerform(iterations: self.selectionClassLabels.count) { index in
            let classLabel = self.selectionClassLabels[index]
            guard let mask = self.binaryMaskFilter.apply(to: segmentationImage, targetValue: classLabel) else {
                print("Failed to generate mask for class label \(classLabel)")
                return
            }
            let objects = self.getObjectsFromBinaryImage(for: mask, classLabel: classLabel, orientation: orientation)
            
            lock.lock()
            objectList.append(contentsOf: objects ?? [])
            lock.unlock()
        }
//        let end = DispatchTime.now()
//        let timeInterval = (end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
//        print("Contour detection time: \(timeInterval) ms")
        return objectList
    }
}
