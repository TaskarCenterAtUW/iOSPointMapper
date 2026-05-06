//
//  ContourRequestProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/5/25.
//
import Vision
import CoreImage

public enum ContourRequestProcessorError: Error, LocalizedError {
    case contourProcessingFailed
    case binaryMaskGenerationFailed
    
    public var errorDescription: String? {
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
 
    TODO: The coordinate system for the detected contours is in normalized coordinates (0 to 1) with the origin at the bottom-left corner.
    This can cause confusion in the app because it pre-dominantly uses Core Video, ARKit, etc. which use a coordinate system with the origin at the top-left corner.
    To reduce confusion, we can preemptively convert the coordinates to the top-left origin. We would also need to change ContourDetails to reflect this change, by not using CGPoint, CGRect, etc. which are based on the bottom-left origin, and instead use a custom struct that can represent the coordinates in the top-left origin.
 */
public struct ContourRequestProcessor {
    public var contourEpsilon: Float = 0.01
    /// For normalized points
    public var perimeterThreshold: Float = 0.01
    public var selectedClasses: [AccessibilityFeatureClass] = []
//    var selectedClassLabels: [UInt8] = []
    
    public var binaryMaskFilter: BinaryMaskFilter
    
    public init(
        contourEpsilon: Float = 0.01, perimeterThreshold: Float = 0.01, selectedClasses: [AccessibilityFeatureClass] = []
    ) throws {
        self.contourEpsilon = contourEpsilon
        self.perimeterThreshold = perimeterThreshold
        self.selectedClasses = selectedClasses
        self.binaryMaskFilter = try BinaryMaskFilter()
    }
    
    public mutating func setSelectedClasses(_ selectedClasses: [AccessibilityFeatureClass]) {
        self.selectedClasses = selectedClasses
    }
    
    private func configureContourRequest(request: VNDetectContoursRequest) {
        request.contrastAdjustment = 1.0
//        request.maximumImageDimension = 256
    }
    
    /**
        Function to rasterize the detected objects on the image. Creates a unique request and handler since it is run on a separate thread
    */
    public func getFeaturesFromBinaryImage(
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
        
        var detectedFeatures = [DetectedAccessibilityFeature]()
        let contours = contourResult?.topLevelContours
        for contour in (contours ?? []) {
            let contourApproximation = try contour.polygonApproximation(epsilon: self.contourEpsilon)
            let contourCentroidAreaBounds = ContourUtils.getCentroidAreaBounds(contour: contourApproximation)
            if contourCentroidAreaBounds.perimeter < self.perimeterThreshold {continue}
            
            detectedFeatures.append(DetectedAccessibilityFeature(
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
        return detectedFeatures
    }
    
    /**
        Function to get the detected objects from the segmentation image.
            Processes each class in parallel to get the objects.
     */
    // TODO: Using DispatchQueue.concurrentPerform for parallel processing may not be the best approach for CPU-bound tasks.
    public func processRequest(
        from segmentationImage: CIImage, orientation: CGImagePropertyOrientation = .up
    ) throws -> [DetectedAccessibilityFeature] {
        var detectedFeatures: [DetectedAccessibilityFeature] = []
        let lock = NSLock()
        DispatchQueue.concurrentPerform(iterations: self.selectedClasses.count) { index in
            do {
//                let targetValue = self.selectedClassLabels[index]
                let targetValue = self.selectedClasses[index].labelValue
                let mask = try self.binaryMaskFilter.apply(to: segmentationImage, targetValue: targetValue)
                let detectedFeaturesFromBinaryImage = try self.getFeaturesFromBinaryImage(
                    for: mask, targetClass: self.selectedClasses[index], orientation: orientation
                )
                
                lock.lock()
                detectedFeatures.append(contentsOf: detectedFeaturesFromBinaryImage)
                lock.unlock()
            } catch {
                print("Error processing contour for class \(self.selectedClasses[index].name): \(error.localizedDescription)")
            }
        }
        return detectedFeatures
    }
}
