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
    var detectedObjects: [UUID: DetectedObject]
    var additionalPayload: [String: Any] = [:] // This can be used to pass additional data if needed
    
    init(segmentationImage: CIImage, segmentationResultUIImage: UIImage, segmentedIndices: [Int],
         detectedObjects: [UUID: DetectedObject], additionalPayload: [String: Any] = [:]) {
        self.segmentationImage = segmentationImage
        self.segmentationResultUIImage = segmentationResultUIImage
        self.segmentedIndices = segmentedIndices
        self.detectedObjects = detectedObjects
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
    @Published var detectedObjects: [UUID: DetectedObject] = [:]
    
    @Published var transformMatrix: simd_float3x3? = nil
//    @Published var transformedFloatingImage: CIImage?
//    @Published var transformedFloatingObjects: [DetectedObject]? = nil
    
//    let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    
    var segmentationModelRequestProcessor: SegmentationModelRequestProcessor?
    var contourRequestProcessor: ContourRequestProcessor?
    var homographyRequestProcessor: HomographyRequestProcessor?
    let centroidTracker = CentroidTracker()
    
    init() {
        self.segmentationModelRequestProcessor = SegmentationModelRequestProcessor(
            selectionClasses: self.selectionClasses)
        self.contourRequestProcessor = ContourRequestProcessor(
            contourEpsilon: self.contourEpsilon,
            perimeterThreshold: self.perimeterThreshold,
            selectionClassLabels: self.selectionClassLabels)
        self.homographyRequestProcessor = HomographyRequestProcessor()
    }
    
    func reset() {
        self.isProcessing = false
        self.setSelectionClasses([])
        self.segmentationImage = nil
        self.segmentationResultUIImage = nil
        self.segmentedIndices = []
        self.detectedObjects = [:]
        self.transformMatrix = nil
        // TODO: No reset function for maskers and processors
        self.centroidTracker.reset()
    }
    
    func setSelectionClasses(_ selectionClasses: [Int]) {
        self.selectionClasses = selectionClasses
        self.selectionClassLabels = selectionClasses.map { Constants.ClassConstants.labels[$0] }
        self.selectionClassGrayscaleValues = selectionClasses.map { Constants.ClassConstants.grayscaleValues[$0] }
        self.selectionClassColors = selectionClasses.map { Constants.ClassConstants.colors[$0] }
        
        self.segmentationModelRequestProcessor?.setSelectionClasses(self.selectionClasses)
        self.contourRequestProcessor?.setSelectionClassLabels(self.selectionClassLabels)
    }
    
    func setCompletionHandler(_ completionHandler: @escaping (Result<SegmentationPipelineResults, Error>) -> Void) {
        self.completionHandler = completionHandler
    }
    
    /**
        Function to process the segmentation request with the given CIImage.
        MARK: Because the orientation issues have been handled in the caller function, we will not be making changes here for now.
     */
    func processRequest(with cIImage: CIImage, previousImage: CIImage?, deviceOrientation: UIDeviceOrientation = .portrait,
                        additionalPayload: [String: Any] = [:]) {
        if self.isProcessing {
            DispatchQueue.main.async {
                self.completionHandler?(.failure(SegmentationPipelineError.isProcessingTrue))
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.isProcessing = true
            let segmentationResults = self.segmentationModelRequestProcessor?.processSegmentationRequest(with: cIImage) ?? nil
            guard let segmentationImage = segmentationResults?.segmentationImage else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.completionHandler?(.failure(SegmentationPipelineError.invalidSegmentation))
                }
                return
            }
           
            // Get the objects from the segmentation image
            let objectList = self.contourRequestProcessor?.processRequest(from: segmentationImage) ?? []

            var transformMatrix: simd_float3x3? = nil
            if let previousImage = previousImage {
                transformMatrix = self.homographyRequestProcessor?.getHomographyTransform(referenceImage: cIImage, floatingImage: previousImage) ?? nil
            }
            self.centroidTracker.update(objectsList: objectList, transformMatrix: transformMatrix)
            
            DispatchQueue.main.async {
                self.segmentationImage = segmentationResults?.segmentationImage
                self.segmentedIndices = segmentationResults?.segmentedIndices ?? []
                self.detectedObjects = Dictionary(uniqueKeysWithValues: self.centroidTracker.objects.map { ($0.key, $0.value) })
                
                // Temporary
//                self.grayscaleToColorMasker.inputImage = segmentationImage
//                self.grayscaleToColorMasker.grayscaleValues = self.selectionClassGrayscaleValues
//                self.grayscaleToColorMasker.colorValues =  self.selectionClassColors
//                self.segmentationResultUIImage = UIImage(
//                    ciImage: self.grayscaleToColorMasker.outputImage!,
//                    scale: 1.0, orientation: .up) // Orientation is handled in processSegmentationRequest
                
                // Temporary
                self.segmentationResultUIImage = UIImage(
                    ciImage: rasterizeContourObjects(
//                        objects: objectList,
                        objects: self.centroidTracker.objects.values.map { $0 },
                        size: Constants.ClassConstants.inputSize)!,
                    scale: 1.0, orientation: .up)
                
//                if transformMatrix != nil {
//                    self.segmentationResultUIImage = UIImage(
//                        ciImage: (self.homographyRequestProcessor?.transformImage(for: previousImage!, using: transformMatrix!))!,
//                        scale: 1.0, orientation: .up)
//                }
//
//                self.transformedFloatingObjects = transformedFloatingObjects
                self.transformMatrix = transformMatrix
                self.completionHandler?(.success(SegmentationPipelineResults(
                    segmentationImage: segmentationImage,
                    segmentationResultUIImage: self.segmentationResultUIImage!,
                    segmentedIndices: self.segmentedIndices,
                    detectedObjects: self.detectedObjects,
                    additionalPayload: additionalPayload
                )))
            }
            self.isProcessing = false
        }
    }
}
