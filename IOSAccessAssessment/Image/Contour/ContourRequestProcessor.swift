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
        for binaryImage: CIImage, targetClass: AccessibilityFeatureClass, orientation: CGImagePropertyOrientation = .up
    ) throws -> [DetectedAccessibilityFeature] {
        let contourRequest = VNDetectContoursRequest()
        self.configureContourRequest(request: contourRequest)
        let contourRequestHandler = VNImageRequestHandler(ciImage: binaryImage, orientation: orientation, options: [:])
        try contourRequestHandler.perform([contourRequest])
        guard let contourResults = contourRequest.results else {
            throw ContourRequestProcessorError.contourProcessingFailed
        }
        
        let contourResult = contourResults.first
        
        var detectedObjects = [DetectedAccessibilityFeature]()
        let contours = contourResult?.topLevelContours
        for contour in (contours ?? []) {
            let contourApproximation = try contour.polygonApproximation(epsilon: self.contourEpsilon)
            let contourCentroidAreaBounds = contourApproximation.getCentroidAreaBounds()
            if contourCentroidAreaBounds.perimeter < self.perimeterThreshold {continue}
            
            detectedObjects.append(DetectedAccessibilityFeature(
                accessibilityFeatureClass: targetClass,
                contourDetails: ContourDetails(
                    centroid: contourCentroidAreaBounds.centroid,
                    boundingBox: contourCentroidAreaBounds.boundingBox,
                    normalizedPoints: contourApproximation.normalizedPoints,
                    area: contourCentroidAreaBounds.area,
                    perimeter: contourCentroidAreaBounds.perimeter
                )
            ))
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
    ) throws -> [DetectedAccessibilityFeature] {
        var detectedObjects: [DetectedAccessibilityFeature] = []
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: self.selectedClasses.count) { index in
            do {
//                let targetValue = self.selectedClassLabels[index]
                let targetValue = self.selectedClasses[index].labelValue
                let mask = try self.binaryMaskFilter.apply(to: segmentationImage, targetValue: targetValue)
                let detectedObjectsFromBinaryImage = try self.getObjectsFromBinaryImage(
                    for: mask, targetClass: self.selectedClasses[index], orientation: orientation
                )
                
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
