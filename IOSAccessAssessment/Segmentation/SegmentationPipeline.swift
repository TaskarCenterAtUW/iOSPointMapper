//
//  SegmentationPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/17/25.
//

import SwiftUI
import Vision
import CoreML

import OrderedCollections
import simd

struct DetectedObject {
    let classLabel: UInt8
    var centroid: CGPoint
    var boundingBox: CGRect
    var normalizedPoints: [SIMD2<Float>]
    var isCurrent: Bool // Indicates if the object is from the current frame or a previous frame
}

enum SegmentationPipelineError: Error, LocalizedError {
    case isProcessingTrue
    case emptySegmentation
    case invalidSegmentation
    case invalidContour
    case invalidTransform
    
    var errorDescription: String? {
        switch self {
        case .isProcessingTrue:
            return "The SegmentationPipeline is already processing a request."
        case .emptySegmentation:
            return "The Segmentation array is Empty"
        case .invalidSegmentation:
            return "The Segmentation is invalid"
        case .invalidContour:
            return "The Contour is invalid"
        case .invalidTransform:
            return "The Homography Transform is invalid"
        }
    }
}

struct SegmentationPipelineResults {
    var segmentationImage: CIImage
    var segmentationResultUIImage: UIImage
    var segmentedIndices: [Int]
    var objects: [UUID: DetectedObject]
    var additionalPayload: [String: Any] = [:] // This can be used to pass additional data if needed
    
    init(segmentationImage: CIImage, segmentationResultUIImage: UIImage, segmentedIndices: [Int],
         objects: [UUID: DetectedObject], additionalPayload: [String: Any] = [:]) {
        self.segmentationImage = segmentationImage
        self.segmentationResultUIImage = segmentationResultUIImage
        self.segmentedIndices = segmentedIndices
        self.objects = objects
        self.additionalPayload = additionalPayload
    }
}

/**
    A class to handle segmentation as well as the post-processing of the segmentation results on demand.
    Currently, a giant monolithic class that handles all the requests. Will be refactored in the future to divide the request types into separate classes.
 */
class SegmentationPipeline: ObservableObject {
    // TODO: Update this to multiple states (one for each of segmentation, contour detection, etc.)
    //  to pipeline the processing.
    //  This will help in more efficiently batching the requests, but will also be quite complex to handle.
    var isProcessing = false
    var completionHandler: ((Result<SegmentationPipelineResults, Error>) -> Void)?
    
    var selectionClasses: [Int] = []
    var selectionClassLabels: [UInt8] = []
    var selectionClassGrayscaleValues: [Float] = []
    var selectionClassColors: [CIColor] = []
    
    var visionModel: VNCoreMLModel
    @Published var segmentationImage: CIImage?
    @Published var segmentedIndices: [Int] = []
    
    // MARK: Temporary segmentationRequest UIImage
    @Published var segmentationResultUIImage: UIImage?
    
    // TODO: Check what would be the appropriate value for this
    var contourEpsilon: Float = 0.01
    // TODO: Check what would be the appropriate value for this
    // For normalized points
    var perimeterThreshold: Float = 0.01
    // While the contour detection logic gives us an array of DetectedObject
    // we get the objects as a dictionary with UUID as the key, from the centroid tracker.
    @Published var objects: [UUID: DetectedObject] = [:]
    
    @Published var transformMatrix: simd_float3x3? = nil
//    @Published var transformedFloatingImage: CIImage?
//    @Published var transformedFloatingObjects: [DetectedObject]? = nil
    
    // TODO: GrayscaleToColorCIFilter will not be restricted to only the selected classes because we are using the ClassConstants
    let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    let binaryMaskProcessor = BinaryMaskProcessor()
    let warpPointsProcessor = WarpPointsProcessor()
    
    let centroidTracker = CentroidTracker()
    
    init() {
        let modelURL = Bundle.main.url(forResource: "espnetv2_pascal_256", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Cannot load CNN model")
        }
        self.visionModel = visionModel
    }
    
    func reset() {
        self.isProcessing = false
        self.setSelectionClasses([])
        self.segmentationImage = nil
        self.segmentationResultUIImage = nil
        self.segmentedIndices = []
        self.objects = [:]
        self.transformMatrix = nil
        // TODO: No reset function for maskers and processors
        self.centroidTracker.reset()
    }
    
    func setSelectionClasses(_ selectionClasses: [Int]) {
        self.selectionClasses = selectionClasses
        self.selectionClassLabels = selectionClasses.map { Constants.ClassConstants.labels[$0] }
        self.selectionClassGrayscaleValues = selectionClasses.map { Constants.ClassConstants.grayscaleValues[$0] }
        self.selectionClassColors = selectionClasses.map { Constants.ClassConstants.colors[$0] }
    }
    
    func setCompletionHandler(_ completionHandler: @escaping (Result<SegmentationPipelineResults, Error>) -> Void) {
        self.completionHandler = completionHandler
    }
    
    func processRequest(with cIImage: CIImage, previousImage: CIImage?, additionalPayload: [String: Any] = [:]) {
        if self.isProcessing {
            DispatchQueue.main.async {
                self.completionHandler?(.failure(SegmentationPipelineError.isProcessingTrue))
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.isProcessing = true
            let segmentationResults = self.processSegmentationRequest(with: cIImage)
            guard let segmentationImage = segmentationResults?.segmentationImage else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.completionHandler?(.failure(SegmentationPipelineError.invalidSegmentation))
                }
                return
            }
//            
            let objectList = self.processContourRequest(from: segmentationImage) ?? []

            var transformMatrix: simd_float3x3? = nil
            if let previousImage = previousImage {
                transformMatrix = self.getHomographyTransform(referenceImage: cIImage, floatingImage: previousImage)
            }
            self.centroidTracker.update(objectsList: objectList, transformMatrix: transformMatrix)
            
            DispatchQueue.main.async {
                self.segmentationImage = segmentationResults?.segmentationImage
                self.segmentedIndices = segmentationResults?.segmentedIndices ?? []
                self.objects = Dictionary(uniqueKeysWithValues: self.centroidTracker.objects.map { ($0.key, $0.value) })
                
                // Temporary
                self.grayscaleToColorMasker.inputImage = segmentationImage
                self.grayscaleToColorMasker.grayscaleValues = self.selectionClassGrayscaleValues
                self.grayscaleToColorMasker.colorValues =  self.selectionClassColors
                self.segmentationResultUIImage = UIImage(ciImage: self.grayscaleToColorMasker.outputImage!,
                                                         scale: 1.0, orientation: .downMirrored)
                
                // Temporary
//                self.segmentationResultUIImage = UIImage(
//                    ciImage: rasterizeContourObjects(objects: objectList, size: Constants.ClassConstants.inputSize)!,
//                    scale: 1.0, orientation: .leftMirrored)
//
//                self.transformedFloatingObjects = transformedFloatingObjects
                self.transformMatrix = transformMatrix
                self.completionHandler?(.success(SegmentationPipelineResults(
                    segmentationImage: segmentationImage,
                    segmentationResultUIImage: self.segmentationResultUIImage!,
                    segmentedIndices: self.segmentedIndices,
                    objects: self.objects,
                    additionalPayload: additionalPayload
                )))
            }
            self.isProcessing = false
        }
    }
}

/**
    Extension of SegmentationPipeline to handle the segmentation requests.
    This extension contains functions to configure the request, process the segmentation image, and get the segmentation results.
 */
extension SegmentationPipeline {
    private func configureSegmentationRequest(request: VNCoreMLRequest) {
        // TODO: Need to check on the ideal options for this
        request.imageCropAndScaleOption = .scaleFill
    }
    
    // MARK: Currently we are relying on the synchronous nature of the request handler
    // Need to check if this is always guaranteed.
    func processSegmentationRequest(with cIImage: CIImage) -> (segmentationImage: CIImage, segmentedIndices: [Int])? {
        do {
            let segmentationRequest = VNCoreMLRequest(model: self.visionModel)
            self.configureSegmentationRequest(request: segmentationRequest)
            // TODO: Check if this is the correct orientation, based on which the UIImage orientation will also be set
            let segmentationRequestHandler = VNImageRequestHandler(ciImage: cIImage, orientation: .right, options: [:])
            try segmentationRequestHandler.perform([segmentationRequest])
            
            guard let segmentationResult = segmentationRequest.results as? [VNPixelBufferObservation] else {return nil}
            let segmentationBuffer = segmentationResult.first?.pixelBuffer
            
            let (_, selectedIndices) = extractUniqueGrayscaleValues(from: segmentationBuffer!)
            let selectedIndicesSet = Set(selectedIndices)
            let segmentedIndices = self.selectionClasses.filter{ selectedIndicesSet.contains($0) }
            
            let segmentationImage = CIImage(cvPixelBuffer: segmentationBuffer!)
            
            return (segmentationImage: segmentationImage, segmentedIndices: segmentedIndices)
        } catch {
            print("Error processing segmentation request: \(error)")
        }
        return nil
    }
}

/**
 Extension of SegmentationPipeline to handle the contour detection requests.
    This extension contains functions to configure the request, process the binary image, and get the detected objects from the segmentation image.
 */
extension SegmentationPipeline {
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
                                                normalizedPoints: contourApproximation.normalizedPoints,
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
    func processContourRequest(from segmentationImage: CIImage) -> [DetectedObject]? {
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
//        print("Contour detection time: \(timeInterval) ms")
        
        return objectList
    }
}

/**
    Extension of SegmentationPipeline to handle the homography transformation requests.
    This extension contains the main functions of homography.
 */
extension SegmentationPipeline {
    /// Computes the homography transform for the reference image and the floating image.
    //      MARK: It seems like the Homography transformation is done the other way around. (floatingImage is the target)
    func getHomographyTransform(referenceImage referenceImage: CIImage, floatingImage: CIImage) -> simd_float3x3? {
        do {
            let transformRequest = VNHomographicImageRegistrationRequest(targetedCIImage: referenceImage)
            let transformRequestHandler = VNImageRequestHandler(ciImage: floatingImage, orientation: .right, options: [:])
            try transformRequestHandler.perform([transformRequest])
            guard let transformResult = transformRequest.results else {return nil}
            let transformMatrix = transformResult.first?.warpTransform
            guard let matrix = transformMatrix else {
                print("Homography transform matrix is nil")
                return nil
            }
            return matrix
        }
        catch {
            print("Error processing homography transform request: \(error)")
            return nil
        }
    }
}


/**
 Helper functions for the SegmentationPipeline class to warp a given image rectangle using a homographic transform matrix.
 */
extension SegmentationPipeline {
    /// Transforms the input point using the provided warpTransform matrix.
    private func warpedPoint(_ point: CGPoint, using warpTransform: simd_float3x3) -> CGPoint {
        let vector0 = SIMD3<Float>(x: Float(point.x), y: Float(point.y), z: 1)
        let vector1 = warpTransform * vector0
        return CGPoint(x: CGFloat(vector1.x / vector1.z), y: CGFloat(vector1.y / vector1.z))
    }
    
    private func transformObjectCentroids(for objects: [DetectedObject], using transformMatrix: simd_float3x3) -> [DetectedObject] {
        return objects.map { object in
            let transformedCentroid = warpedPoint(object.centroid, using: transformMatrix)
            return DetectedObject(
                classLabel: object.classLabel,
                centroid: transformedCentroid,
                boundingBox: object.boundingBox,
                normalizedPoints: object.normalizedPoints,
                isCurrent: object.isCurrent
            )
        }
    }
    
    /// This is a quadrilateral defined by four corner points.
    private struct Quad {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
    }
    
    /// Warps the input rectangle using the warpTransform matrix, and returns the warped Quad.
    private func makeWarpedQuad(for rect: CGRect, using warpTransform: simd_float3x3) -> Quad {
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        
        let topLeft = CGPoint(x: minX, y: maxY)
        let topRight = CGPoint(x: maxX, y: maxY)
        let bottomLeft = CGPoint(x: minX, y: minY)
        let bottomRight = CGPoint(x: maxX, y: minY)
        
        let warpedTopLeft = warpedPoint(topLeft, using: warpTransform)
        let warpedTopRight = warpedPoint(topRight, using: warpTransform)
        let warpedBottomLeft = warpedPoint(bottomLeft, using: warpTransform)
        let warpedBottomRight = warpedPoint(bottomRight, using: warpTransform)
        
        return Quad(topLeft: warpedTopLeft,
                    topRight: warpedTopRight,
                    bottomLeft: warpedBottomLeft,
                    bottomRight: warpedBottomRight)
    }
    
    private func transformImage(for floatingImage: CIImage, using transformMatrix: simd_float3x3) -> CIImage? {
        let quad = makeWarpedQuad(for: floatingImage.extent, using: transformMatrix)
        // Creates the alignedImage by warping the floating image using the warpTransform from the homographic observation.
        let transformParameters = [
            "inputTopLeft": CIVector(cgPoint: quad.topLeft),
            "inputTopRight": CIVector(cgPoint: quad.topRight),
            "inputBottomRight": CIVector(cgPoint: quad.bottomRight),
            "inputBottomLeft": CIVector(cgPoint: quad.bottomLeft)
        ]
        
        let transformedImage = floatingImage.applyingFilter("CIPerspectiveTransform", parameters: transformParameters)
        return transformedImage
    }
    
//    func processTransformFloatingObjectsRequest(referenceImage: CIImage, floatingImage: CIImage, floatingObjects: [DetectedObject]) -> [DetectedObject]? {
//        let start = DispatchTime.now()
//        let transformMatrix = self.getHomographyTransform(for: referenceImage, floatingImage: floatingImage)
////            let transformImage = self.transformImage(for: floatingImage, using: transformMatrix!)
//        let transformedObjects = self.transformObjectCentroids(for: floatingObjects, using: transformMatrix!)
//        let end = DispatchTime.now()
//        let timeInterval = (end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
////            print("Transform floating image time: \(timeInterval) ms")
//        return transformedObjects
//    }
    
}
    
