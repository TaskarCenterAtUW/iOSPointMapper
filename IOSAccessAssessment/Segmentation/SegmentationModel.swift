//
//  SegmentationModel.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//

import SwiftUI
import Vision
import CoreML

enum SegmentationError: Error, LocalizedError {
    case emptySegmentation
    case invalidSegmentation
    
    var errorDescription: String? {
        switch self {
        case .emptySegmentation:
            return "The Segmentation array is Empty"
        case .invalidSegmentation:
            return "The Segmentation is invalid"
        }
    }
}

struct SegmentationResultsOutput {
    var segmentationResults: CIImage
    var maskedSegmentationResults: UIImage
    var segmentedIndices: [Int]
    
    init(segmentationResults: CIImage, maskedSegmentationResults: UIImage, segmentedIndices: [Int]) {
        self.segmentationResults = segmentationResults
        self.maskedSegmentationResults = maskedSegmentationResults
        self.segmentedIndices = segmentedIndices
    }
}

struct PerClassSegmentationResultsOutput {
    var segmentationLabelResults: CIImage
    var perClassSegmentationResults: [CIImage]
    var segmentedIndices: [Int]
    
    init(segmentationLabelResults: CIImage, perClassSegmentationResults: [CIImage], segmentedIndices: [Int]) {
        self.segmentationLabelResults = segmentationLabelResults
        self.perClassSegmentationResults = perClassSegmentationResults
        self.segmentedIndices = segmentedIndices
    }
}

/** A class to handle segmentation of images by loading them in a queue.
 
 # Overview
 This Segmentation Model can perform two kinds of requests.
 1. All-class segmentation (only one output image) and Per class segmentation (one image per class)
 2. Also saves colored masks of the segmentation results.
 
 */
class SegmentationModel: ObservableObject {
    @Published var segmentationResults: CIImage?
    @Published var maskedSegmentationResults: UIImage?
    // Not in use for the current system. All usages have been commented out
//    @Published
    var isSegmentationProcessing: Bool = false
    private(set) var segmentationRequests: [VNRequest] = [VNRequest]()
    
    @Published var perClassSegmentationResults: [CIImage]?
    // Not in use for the current system. All usages have been commented out
//    @Published
    var isPerClassSegmentationProcessing: Bool = false
    private(set) var perClassSegmentationRequests: [VNRequest] = [VNRequest]()
    
    @Published var segmentedIndices: [Int] = []
    
    var visionModel: VNCoreMLModel
    
    // TODO: Check if replacing the custom CIFilter with a plain class would help improve performance.
    //  We are not chaining additional filters, thus using CIFilter doesn't seem to make much sense.
    let masker = GrayscaleToColorCIFilter()

    init() {
        let modelURL = Bundle.main.url(forResource: "bisenetv2", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Cannot load CNN model")
        }
        self.visionModel = visionModel
    }
    
    func updateSegmentationRequest(selection: [Int], completion: @escaping (Result<SegmentationResultsOutput, Error>) -> Void) {
        let segmentationRequests = VNCoreMLRequest(model: self.visionModel, completionHandler: {request, error in
            DispatchQueue.main.async(execute: {
                if let results = request.results {
                    self.processSegmentationRequest(results, selection, completion: completion)
                }
            })
        })
        segmentationRequests.imageCropAndScaleOption = .scaleFill
        self.segmentationRequests = [segmentationRequests]
    }
    
    func processSegmentationRequest(_ observations: [Any], _ selection: [Int],
                                    completion: @escaping (Result<SegmentationResultsOutput, Error>) -> Void){
        let obs = observations as! [VNPixelBufferObservation]
        if obs.isEmpty{
            print("The Segmentation array is Empty")
            completion(.failure(SegmentationError.emptySegmentation))
            return
        }

        let outPixelBuffer = (obs.first)!
        let (_, selectedIndices) = extractUniqueGrayscaleValues(from: outPixelBuffer.pixelBuffer)
        
        let selectedIndicesSet = Set(selectedIndices)
        let segmentedIndices = selection.filter{ selectedIndicesSet.contains($0) }
        
        let outputImage = CIImage(cvPixelBuffer: outPixelBuffer.pixelBuffer)
        self.masker.inputImage = outputImage
        
        // TODO: Instead of passing new grayscaleValues and colorValues to the custom CIFilter for every new image
        // Check if you can instead simply pass the constants as the parameters during the filter initialization
        self.masker.grayscaleValues = selection.map { Constants.ClassConstants.grayscaleValues[$0] }
        self.masker.colorValues =  selection.map { Constants.ClassConstants.colors[$0] }
        
        self.segmentedIndices = segmentedIndices
        self.segmentationResults = outputImage
        self.maskedSegmentationResults = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .downMirrored)
        if let _ = self.segmentationResults,
            let maskedSegmentationImage = self.maskedSegmentationResults {
            completion(.success(SegmentationResultsOutput(
                segmentationResults: outputImage,
                maskedSegmentationResults: maskedSegmentationImage,
                segmentedIndices: segmentedIndices)))
        } else {
            completion(.failure(SegmentationError.invalidSegmentation))
        }
    }

    func performSegmentationRequest(with ciImage: CIImage) {
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .right, options: [:])
        do {
            try handler.perform(self.segmentationRequests)
        } catch {
            print("Error performing request: \(error.localizedDescription)")
        }
    }
    
    func updatePerClassSegmentationRequest(selection: [Int], completion: @escaping (Result<PerClassSegmentationResultsOutput, Error>) -> Void) {
        let perClassSegmentationRequests = VNCoreMLRequest(model: self.visionModel, completionHandler: {request, error in
            DispatchQueue.main.async(execute: {
                if let results = request.results {
                    self.processPerClassSegmentationRequest(results, selection, completion: completion)
                }
            })
        })
        perClassSegmentationRequests.imageCropAndScaleOption = .scaleFill
        self.perClassSegmentationRequests = [perClassSegmentationRequests]
    }
    
    func processPerClassSegmentationRequest(_ observations: [Any], _ selection: [Int],
                                            completion: @escaping (Result<PerClassSegmentationResultsOutput, Error>) -> Void){
        let obs = observations as! [VNPixelBufferObservation]
        if obs.isEmpty{
            print("The Segmentation array is Empty")
            completion(.failure(SegmentationError.emptySegmentation))
            return
        }

        let outPixelBuffer = (obs.first)!
        let (_, selectedIndices) = extractUniqueGrayscaleValues(from: outPixelBuffer.pixelBuffer)
        
        let selectedIndicesSet = Set(selectedIndices)
        let segmentedIndices = selection.filter{ selectedIndicesSet.contains($0) }
        
        let outputImage = CIImage(cvPixelBuffer: outPixelBuffer.pixelBuffer)
        self.masker.inputImage = outputImage
        
        let totalCount = segmentedIndices.count
        var perClassSegmentationResults = [CIImage](repeating: CIImage(), count: totalCount)
        // For each class, extract the separate segment
        for i in segmentedIndices.indices {
            let currentClass = segmentedIndices[i]
            self.masker.grayscaleValues = [Constants.ClassConstants.grayscaleValues[currentClass]]
            self.masker.colorValues = [Constants.ClassConstants.colors[currentClass]]
            perClassSegmentationResults[i] = self.masker.outputImage!
        }
        
        self.perClassSegmentationResults = perClassSegmentationResults
        if let perClassSegmentationImages = self.perClassSegmentationResults {
            completion(.success(PerClassSegmentationResultsOutput(
                segmentationLabelResults: outputImage,
                perClassSegmentationResults: perClassSegmentationImages, segmentedIndices: segmentedIndices
            )))
        } else {
            completion(.failure(SegmentationError.invalidSegmentation))
        }
    }
    
    func performPerClassSegmentationRequest(with ciImage: CIImage) {
        print("performPerClassSegmentationRequest")
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: .right, options: [:])
        do {
            try handler.perform(self.perClassSegmentationRequests)
        } catch {
            print("Error performing request: \(error.localizedDescription)")
        }
    }
}

// Private helper functions
extension SegmentationModel {
    private func extractUniqueGrayscaleValues(from pixelBuffer: CVPixelBuffer) -> (Set<UInt8>, [Int]) {
        var uniqueValues = Set<UInt8>()
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bitDepth = 8 // Assuming 8 bits per component in a grayscale image.
        
        let byteBuffer = baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        for row in 0..<height {
            for col in 0..<width {
                let offset = row * bytesPerRow + col * (bitDepth / 8)
                let value = byteBuffer[offset]
                uniqueValues.insert(value)
            }
        }
        
        let valueToIndex = Dictionary(uniqueKeysWithValues: Constants.ClassConstants.grayscaleValues.enumerated().map { ($0.element, $0.offset) })
        
        // MARK: sorting may not be necessary for our use case
        let selectedIndices = uniqueValues.map { UInt8($0) }
            .map {Float($0) / 255.0 }
            .compactMap { valueToIndex[$0]}
            .sorted()
            
        return (uniqueValues, selectedIndices)
    }
    
    // Get the grayscale values and the corresponding colors
    private func getGrayScaleAndColorsFromSelection(selection: [Int], classes: [String], labelToClassNameMap: [UInt8: String], grayValues: [Float]) -> ([UInt8], [CIColor]) {
        let selectedClasses = selection.map { classes[$0] }
        var selectedGrayscaleValues: [UInt8] = []
        var selectedColors: [CIColor] = []

        for (key, value) in labelToClassNameMap {
            if !selectedClasses.contains(value) { continue }
            selectedGrayscaleValues.append(key)
            // Assuming grayValues contains grayscale/255, find the index of the grayscale value that matches the key
            if let index = grayValues.firstIndex(of: Float(key)) {
                selectedColors.append(Constants.ClassConstants.colors[index])
                // Fetch corresponding color using the same index
            }
        }

        return (selectedGrayscaleValues, selectedColors)
    }
    
    private func preprocessPixelBuffer(_ pixelBuffer: CVPixelBuffer, withSelectedGrayscaleValues selectedValues: [UInt8]) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = CVPixelBufferGetBaseAddress(pixelBuffer)

        let pixelBufferFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        
        guard pixelBufferFormat == kCVPixelFormatType_OneComponent8 else {
            print("Pixel buffer format is not 8-bit grayscale.")
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return
        }

        let selectedValuesSet = Set(selectedValues) // Improve lookup performance
        
        for row in 0..<height {
            let rowBase = buffer!.advanced(by: row * bytesPerRow)
            for column in 0..<width {
                let pixel = rowBase.advanced(by: column)
                let pixelValue = pixel.load(as: UInt8.self)
                if !selectedValuesSet.contains(pixelValue) {
                    // Setting unselected values to 0
                    pixel.storeBytes(of: 0, as: UInt8.self)
                }
            }
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
}
