//
//  ContourRequestProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/5/25.
//
import Vision
import CoreImage

enum ContourRequestProcessorError: Error, LocalizedError {
    case contourProcessingFailed
    case binaryMaskGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .contourProcessingFailed:
            return "Contour processing failed."
        case .binaryMaskGenerationFailed:
            return "Binary mask generation failed for contour detection."
        }
    }
}

/**
    ContourRequestProcessor is a struct that processes contour detection requests using Vision framework.
    It performs the contour detection concurrently for each class label in the segmentation image.
 */
struct ContourRequestProcessor {
    var contourEpsilon: Float = 0.01
    // For normalized points
    var perimeterThreshold: Float = 0.01
    var selectedClasses: [AccessibilityFeatureClass] = []
//    var selectedClassLabels: [UInt8] = []
    
    var binaryMaskFilter: BinaryMaskFilter
    
    init(
        contourEpsilon: Float = 0.01, perimeterThreshold: Float = 0.01, selectedClasses: [AccessibilityFeatureClass] = []
    ) throws {
        self.contourEpsilon = contourEpsilon
        self.perimeterThreshold = perimeterThreshold
        self.selectedClasses = selectedClasses
        self.binaryMaskFilter = try BinaryMaskFilter()
    }
    
    mutating func setSelectedClasses(_ selectedClasses: [AccessibilityFeatureClass]) {
        self.selectedClasses = selectedClasses
    }
    
    private func configureContourRequest(request: VNDetectContoursRequest) {
        request.contrastAdjustment = 1.0
//        request.maximumImageDimension = 256
    }
    
    /**
        Function to rasterize the detected objects on the image. Creates a unique request and handler since it is run on a separate thread
    */
    func getObjectsFromBinaryImage(
        for binaryImage: CIImage, classLabel: UInt8, orientation: CGImagePropertyOrientation = .up
    ) throws -> [DetectedObject] {
        let contourRequest = VNDetectContoursRequest()
        self.configureContourRequest(request: contourRequest)
        let contourRequestHandler = VNImageRequestHandler(ciImage: binaryImage, orientation: orientation, options: [:])
        try contourRequestHandler.perform([contourRequest])
        guard let contourResults = contourRequest.results else {
            throw ContourRequestProcessorError.contourProcessingFailed
        }
        
        let contourResult = contourResults.first
        
        var detectedObjects = [DetectedObject]()
        let contours = contourResult?.topLevelContours
        for contour in (contours ?? []) {
            let contourApproximation = try contour.polygonApproximation(epsilon: self.contourEpsilon)
            let contourDetails = contourApproximation.getCentroidAreaBounds()
            if contourDetails.perimeter < self.perimeterThreshold {continue}
            
            detectedObjects.append(DetectedObject(classLabel: classLabel,
                                            centroid: contourDetails.centroid,
                                            boundingBox: contourDetails.boundingBox,
                                            normalizedPoints: contourApproximation.normalizedPoints,
                                            area: contourDetails.area,
                                            perimeter: contourDetails.perimeter,
                                            isCurrent: true))
        }
        return detectedObjects
    }
    
    /**
        Function to get the detected objects from the segmentation image.
            Processes each class in parallel to get the objects.
     */
    // TODO: Using DispatchQueue.concurrentPerform for parallel processing may not be the best approach for CPU-bound tasks.
    func processRequest(
        from segmentationImage: CIImage, orientation: CGImagePropertyOrientation = .up
    ) throws -> [DetectedObject] {
        var detectedObjects: [DetectedObject] = []
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: self.selectedClasses.count) { index in
            do {
//                let classLabel = self.selectedClassLabels[index]
                let classLabel = self.selectedClasses[index].labelValue
                let mask = try self.binaryMaskFilter.apply(to: segmentationImage, targetValue: classLabel)
                let detectedObjectsFromBinaryImage = try self.getObjectsFromBinaryImage(for: mask, classLabel: classLabel, orientation: orientation)
                
                lock.lock()
                detectedObjects.append(contentsOf: detectedObjectsFromBinaryImage)
                lock.unlock()
            } catch {
                print("Error processing contour for class \(self.selectedClasses[index].name): \(error.localizedDescription)")
            }
        }
        return detectedObjects
    }
}

// Functions to get contour details including centroid, area, bounding box, and perimeter
extension ContourRequestProcessor {
    /**
        Function to get the bounding box of the contour as a trapezoid. This is the largest trapezoid that can be contained in the contour and has horizontal lines.
        - Parameters:
            - points: The points of the contour
            - x_delta: The delta for the x-axis (minimum distance between points)
            - y_delta: The delta for the y-axis (minimum distance between points)
     */
    // TODO: Check if the performance can be improved by using SIMD operations
    /**
     FIXME: This function suffers from an edge case
     Let's say the contour has a very small line at its lowest point, but just above it has a very wide line.
     In such a case, the function should probably return a trapezoid with the wider lower line,
     but it returns the trapezoid with the smaller line.
     We may have to come up with a better heuristic to determine the right shape for getting the way bounds.
     */
    func getContourTrapezoid(from points: [SIMD2<Float>], x_delta: Float = 0.1, y_delta: Float = 0.1) -> [SIMD2<Float>]? {
//        let points = contour.normalizedPoints
        guard !points.isEmpty else { return nil }
        
//        let minPointsForComparison = points.count
        
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
}
