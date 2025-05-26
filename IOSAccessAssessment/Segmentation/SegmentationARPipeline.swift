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

enum SegmentationARPipelineError: Error, LocalizedError {
    case isProcessingTrue
    case emptySegmentation
    case invalidSegmentation
    case invalidContour
    case invalidTransform
    case unexpectedError
    
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
        case .unexpectedError:
            return "An unexpected error occurred in the SegmentationARPipeline."
        }
    }
}

struct SegmentationARPipelineResults {
    var segmentationImage: CIImage
    var segmentationResultUIImage: UIImage
    var segmentedIndices: [Int]
    var detectedObjectMap: [UUID: DetectedObject]
    var transformMatrixFromPreviousFrame: simd_float3x3? = nil
    var additionalPayload: [String: Any] = [:] // This can be used to pass additional data if needed
    
    init(segmentationImage: CIImage, segmentationResultUIImage: UIImage, segmentedIndices: [Int],
         detectedObjectMap: [UUID: DetectedObject], transformMatrixFromPreviousFrame: simd_float3x3? = nil,
         additionalPayload: [String: Any] = [:]) {
        self.segmentationImage = segmentationImage
        self.segmentationResultUIImage = segmentationResultUIImage
        self.segmentedIndices = segmentedIndices
        self.detectedObjectMap = detectedObjectMap
        self.transformMatrixFromPreviousFrame = transformMatrixFromPreviousFrame
        self.additionalPayload = additionalPayload
    }
}

/**
    A class to handle segmentation as well as the post-processing of the segmentation results on demand.
    Currently, a giant monolithic class that handles all the requests. Will be refactored in the future to divide the request types into separate classes.
 */
class SegmentationARPipeline: ObservableObject {
    // TODO: Update this to multiple states (one for each of segmentation, contour detection, etc.)
    //  to pipeline the processing.
    //  This will help in more efficiently batching the requests, but will also be quite complex to handle.
    var isProcessing = false
    var completionHandler: ((Result<SegmentationARPipelineResults, Error>) -> Void)?
    
    var selectionClasses: [Int] = []
    var selectionClassLabels: [UInt8] = []
    var selectionClassGrayscaleValues: [Float] = []
    var selectionClassColors: [CIColor] = []
    
    var segmentationImage: CIImage?
    var segmentedIndices: [Int] = []
    // MARK: Temporary segmentationRequest UIImage. Later we should move this mapping to the SharedImageData in ContentView
    @Published var segmentationResultUIImage: UIImage?
    
    // TODO: Check what would be the appropriate value for this
    var contourEpsilon: Float = 0.01
    // TODO: Check what would be the appropriate value for this
    // For normalized points
    var perimeterThreshold: Float = 0.01
    // While the contour detection logic gives us an array of DetectedObject
    // we get the detected objects as a dictionary with UUID as the key, from the centroid tracker.
    var detectedObjectMap: [UUID: DetectedObject] = [:]
    
    // Transformation matrix from the previous frame to the current frame
    var transformMatrixFromPreviousFrame: simd_float3x3? = nil
    
    let grayscaleToColorMasker = GrayscaleToColorCIFilter()
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
        self.detectedObjectMap = [:]
        self.transformMatrixFromPreviousFrame = nil
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
    
    func setCompletionHandler(_ completionHandler: @escaping (Result<SegmentationARPipelineResults, Error>) -> Void) {
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
            
            do {
                let processedImageResults = try self.processImage(
                    cIImage, previousImage: previousImage, deviceOrientation: deviceOrientation
                )
                DispatchQueue.main.async {
                    self.segmentationImage = processedImageResults.segmentationImage
                    self.segmentedIndices = processedImageResults.segmentedIndices
                    self.detectedObjectMap = processedImageResults.detectedObjectMap
                    self.transformMatrixFromPreviousFrame = processedImageResults.transformMatrixFromPreviousFrame
                    self.segmentationResultUIImage = processedImageResults.segmentationResultUIImage
                    
                    self.completionHandler?(.success(SegmentationARPipelineResults(
                        segmentationImage: processedImageResults.segmentationImage,
                        segmentationResultUIImage: processedImageResults.segmentationResultUIImage,
                        segmentedIndices: processedImageResults.segmentedIndices,
                        detectedObjectMap: processedImageResults.detectedObjectMap,
                        transformMatrixFromPreviousFrame: processedImageResults.transformMatrixFromPreviousFrame,
                        additionalPayload: additionalPayload
                    )))
                }
            } catch let error as SegmentationARPipelineError {
                DispatchQueue.main.async {
                    self.completionHandler?(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    self.completionHandler?(.failure(SegmentationARPipelineError.unexpectedError))
                }
            }
            self.isProcessing = false
        }
    }
    
    func processFinalRequest(with cIImage: CIImage, previousImage: CIImage?, deviceOrientation: UIDeviceOrientation = .portrait,
                             additionalPayload: [String: Any] = [:]) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Wait for the current processing to finish
            while self.isProcessing {
                Thread.sleep(forTimeInterval: 0.01) // Sleep for a short duration to avoid busy waiting
            }
            self.isProcessing = true
            
            do {
                let processedImageResults = try self.processImage(
                    cIImage, previousImage: previousImage, deviceOrientation: deviceOrientation
                )
                DispatchQueue.main.async {
                    self.segmentationImage = processedImageResults.segmentationImage
                    self.segmentedIndices = processedImageResults.segmentedIndices
                    self.detectedObjectMap = processedImageResults.detectedObjectMap
                    self.transformMatrixFromPreviousFrame = processedImageResults.transformMatrixFromPreviousFrame
                    self.segmentationResultUIImage = processedImageResults.segmentationResultUIImage
                    
                    self.completionHandler?(.success(SegmentationARPipelineResults(
                        segmentationImage: processedImageResults.segmentationImage,
                        segmentationResultUIImage: processedImageResults.segmentationResultUIImage,
                        segmentedIndices: processedImageResults.segmentedIndices,
                        detectedObjectMap: processedImageResults.detectedObjectMap,
                        transformMatrixFromPreviousFrame: processedImageResults.transformMatrixFromPreviousFrame,
                        additionalPayload: additionalPayload
                    )))
                }
            } catch let error as SegmentationARPipelineError {
                DispatchQueue.main.async {
                    self.completionHandler?(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    self.completionHandler?(.failure(SegmentationARPipelineError.unexpectedError))
                }
            }
            self.isProcessing = false
        }
    }
    
    /**
     Function to process the given CIImage.
     This function will perform the processing within the thread in which it is called.
     It does not check if the pipeline is already processing a request, or even look for the completion handler.
     It will either return the SegmentationARPipelineResults or throw an error.
     
     The entire procedure has the following main steps:
     1. Get the segmentation mask from the camera image using the segmentation model
     2. Get the objects from the segmentation image
     3. Get the homography transform matrix from the previous image to the current image
     4. Update the centroid tracker with the detected objects and the transform matrix (Currently, the results of this are not effectively utilized)
     5. Return the segmentation image, segmented indices, detected objects, and the transform matrix to the caller function
     */
    func processImage(_ cIImage: CIImage, previousImage: CIImage? = nil,
                      deviceOrientation: UIDeviceOrientation = .portrait) throws -> SegmentationARPipelineResults {
        let segmentationResults = self.segmentationModelRequestProcessor?.processSegmentationRequest(with: cIImage) ?? nil
        guard let segmentationImage = segmentationResults?.segmentationImage else {
            throw SegmentationARPipelineError.invalidSegmentation
        }
        
        // Get the objects from the segmentation image
        let detectedObjects = self.contourRequestProcessor?.processRequest(from: segmentationImage) ?? []

        // If a previous image is provided, get the homography transform matrix from the previous image to the current image
        var transformMatrixFromPreviousFrame: simd_float3x3? = nil
        if let previousImage = previousImage {
            transformMatrixFromPreviousFrame = self.homographyRequestProcessor?.getHomographyTransform(
                referenceImage: cIImage, floatingImage: previousImage) ?? nil
        }
        self.centroidTracker.update(objects: detectedObjects, transformMatrix: transformMatrixFromPreviousFrame)
        
        self.grayscaleToColorMasker.inputImage = segmentationImage
        self.grayscaleToColorMasker.grayscaleValues = self.selectionClassGrayscaleValues
        self.grayscaleToColorMasker.colorValues =  self.selectionClassColors
        let segmentationResultUIImage = UIImage(
            ciImage: self.grayscaleToColorMasker.outputImage!,
            scale: 1.0, orientation: .up) // Orientation is handled in processSegmentationRequest
        
        return SegmentationARPipelineResults(
            segmentationImage: segmentationImage,
            segmentationResultUIImage: segmentationResultUIImage,
            segmentedIndices: segmentationResults?.segmentedIndices ?? [],
            detectedObjectMap: Dictionary(uniqueKeysWithValues: self.centroidTracker.detectedObjectMap.map { ($0.key, $0.value) }),
            transformMatrixFromPreviousFrame: transformMatrixFromPreviousFrame
        )
    }
    
}
