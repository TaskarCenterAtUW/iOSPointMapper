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
                                                area: contourDetails.area,
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
    private func getContourDetails(from contour: VNContour) -> (centroid: CGPoint, boundingBox: CGRect, perimeter: Float, area: Float) {
        let points = contour.normalizedPoints
        guard !points.isEmpty else { return (CGPoint.zero, .zero, 0, 0) }
        
        let centroidAreaResults = self.getContourCentroidAndArea(from: contour)
        let boundingBox = self.getContourBoundingBox(from: contour)
        let perimeter = self.getContourPerimeter(from: contour)
        
        return (centroid: centroidAreaResults.centroid, boundingBox, perimeter, centroidAreaResults.area)
    }
    
    /**
     Use shoelace formula to calculate the area of the contour.
     */
    private func getContourCentroidAndArea(from contour: VNContour) -> (centroid: CGPoint, area: Float) {
        let points = contour.normalizedPoints
        guard !points.isEmpty else { return (CGPoint.zero, 0) }
        
        let count = points.count
        
        var area: Float = 0.0
        var cx: Float = 0.0
        var cy: Float = 0.0
        
        guard count > 2 else {
            cx = points.map { $0.x }.reduce(0, +) / Float(points.count)
            cy = points.map { $0.y }.reduce(0, +) / Float(points.count)
            let centroid = CGPoint(x: CGFloat(cx), y: CGFloat(cy))
            return (centroid, 0)
        }
        
        for i in 0..<count {
            let p0 = points[i]
            let p1 = points[(i + 1) % count] // wrap around to the first point
            
            let crossProduct = (p0.x * p1.y) - (p1.x * p0.y)
            area += crossProduct
            cx += (p0.x + p1.x) * crossProduct
            cy += (p0.y + p1.y) * crossProduct
        }
        
        area = 0.5 * abs(area)
        guard area > 0 else { return (CGPoint.zero, 0) }
        
        cx /= (6 * area)
        cy /= (6 * area)
        
        let centroid = CGPoint(x: CGFloat(cx), y: CGFloat(cy))
        return (centroid, area)
    }
    
    private func getContourBoundingBox(from contour: VNContour) -> CGRect {
        let points = contour.normalizedPoints
        guard !points.isEmpty else { return .zero }
        
        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y
        
        for i in 0..<(points.count - 1) {
            minX = min(minX, points[i].x)
            minY = min(minY, points[i].y)
            maxX = max(maxX, points[i].x)
            maxY = max(maxY, points[i].y)
        }
        
        return CGRect(
            x: CGFloat(minX), y: CGFloat(minY),
            width: CGFloat(maxX - minX), height: CGFloat(maxY - minY)
        )
    }
    
    private func getContourPerimeter(from contour: VNContour) -> Float {
        let points = contour.normalizedPoints
        guard !points.isEmpty else { return 0 }
        
        var perimeter: Float = 0.0
        let count = points.count
        
        for i in 0..<count {
            let p0 = points[i]
            let p1 = points[(i + 1) % count] // wrap around to the first point
            
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            perimeter += sqrt(dx*dx + dy*dy)
        }
        
        return perimeter
    }



        
    
    /**
        Function to get the bounding box of the contour as a trapezoid. This is the largest trapezoid that can be contained in the contour and has horizontal lines.
     
     
        - Parameters:
            - points: The points of the contour
            - x_delta: The delta for the x-axis (minimum distance between points)
            - y_delta: The delta for the y-axis (minimum distance between points)
     */
    // TODO: Check if the performance can be improved by using SIMD operations
    // FIXME: Currently, this function does not guarantee that the trapezoid is valid.
    // The trapezoid may actually have incorrect points.
    func getContourTrapezoid(from points: [SIMD2<Float>], x_delta: Float = 0.1, y_delta: Float = 0.1) -> [SIMD2<Float>]? {
//        let points = contour.normalizedPoints
        guard !points.isEmpty else { return nil }
        
        let minPointsForComparison = points.count
        
        let sortedByYPoints = points.sorted(by: { $0.y < $1.y })
        
        func intersectsAtY(p1: SIMD2<Float>, p2: SIMD2<Float>, y0: Float) -> SIMD2<Float>? {
            // Check if y0 is between y1 and y2
            if (y0 - p1.y) * (y0 - p2.y) <= 0 && p1.y != p2.y {
                // Linear interpolation to find x
                let t = (y0 - p1.y) / (p2.y - p1.y)
                let x = p1.x + t * (p2.x - p1.x)
                return SIMD2<Float>(x, y0)
            }
            return nil
        }
        
        var upperLeftX: Float? = nil
        var upperRightX: Float? = nil
        var lowerLeftX: Float? = nil
        var lowerRightX: Float? = nil
        
        // Status flags
        var upperLineFound = false
        var lowerLineFound = false
        
        // With two-pointer approach
        var lowY = 0
        var highY = points.count - 1
        while lowY < highY {
            if sortedByYPoints[lowY].y > (sortedByYPoints[highY].y - y_delta) {
                return nil
            }
            // Check all the lines in the contour
            // on whether they intersect with lowY or highY
            for i in 0..<points.count {
                let point1 = points[i]
                let point2 = points[(i + 1) % points.count]
                
                if (!lowerLineFound) {
                    let intersection1 = intersectsAtY(p1: point1, p2: point2, y0: sortedByYPoints[lowY].y)
                    if let intersection1 = intersection1 {
                        if (intersection1.x < (lowerLeftX ?? 2)) {
                            lowerLeftX = intersection1.x
                        }
                        if (intersection1.x > (lowerRightX ?? -1)) {
                            lowerRightX = intersection1.x
                        }
                    }
                }
                
                if (!upperLineFound) {
                    let intersection2 = intersectsAtY(p1: point1, p2: point2, y0: sortedByYPoints[highY].y)
                    if let intersection2 = intersection2 {
                        if (intersection2.x < (upperLeftX ?? 2)) {
                            upperLeftX = intersection2.x
                        }
                        if (intersection2.x > (upperRightX ?? -1)) {
                            upperRightX = intersection2.x
                        }
                    }
                }
            }
            if !lowerLineFound {
                if lowerLeftX != nil && lowerRightX != nil && (lowerLeftX! < lowerRightX! - x_delta) {
                    lowerLineFound = true
                } else {
                    lowerLeftX = nil
                    lowerRightX = nil
                }
            }
            if !upperLineFound {
                if upperLeftX != nil && upperRightX != nil && (upperLeftX! < upperRightX! - x_delta) {
                    upperLineFound = true
                } else {
                    upperLeftX = nil
                    upperRightX = nil
                }
            }
            if upperLineFound && lowerLineFound {
                return [
                    SIMD2<Float>(lowerLeftX!, sortedByYPoints[lowY].y),
                    SIMD2<Float>(upperLeftX!, sortedByYPoints[highY].y),
                    SIMD2<Float>(upperRightX!, sortedByYPoints[highY].y),
                    SIMD2<Float>(lowerRightX!, sortedByYPoints[lowY].y)
                ]
            }
            
            if !lowerLineFound{
                lowY += 1
            }
            if !upperLineFound{
                highY -= 1
            }
        }
        
        return nil
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
