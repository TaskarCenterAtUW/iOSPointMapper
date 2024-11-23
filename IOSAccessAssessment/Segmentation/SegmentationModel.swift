//
//  SegmentationModel.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/22/24.
//

import SwiftUI
import Vision
import CoreML

// This Segmentation Model can perform two kinds of requests
// All-class segmentation (only one output image) and Per class segmentation (one image per class)
class SegmentationModel: ObservableObject {
    @Published var segmentationResults: UIImage?
    // Not in use for the current system. All usages have been commented out
    @Published var isSegmentationProcessing: Bool = false
    private(set) var segmentationRequests: [VNRequest] = []
    
    @Published var perClassSegmentationResults: [Any]?
    @Published var isPerClassSegmentationProcessing: Bool = false
    private(set) var perClassSegmentationRequests: [VNRequest] = []
    
    @Published var segmentedIndices: [Int] = []
    
    var visionModel: VNCoreMLModel
    
    // TODO: Check if replacing the custom CIFilter with a plain class would help improve performance.
    //  We are not chaining additional filters, thus using CIFilter doesn't seem to make much sense.
    let masker = GrayscaleToColorCIFilter()

    init() {
        let modelURL = Bundle.main.url(forResource: "deeplabv3plus_mobilenet", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Cannot load CNN model")
        }
        self.visionModel = visionModel
    }
    
    func updateSegmentationRequests(selection: [Int]) {
        let segmentationRequests = VNCoreMLRequest(model: self.visionModel, completionHandler: {request, error in
            DispatchQueue.main.async(execute: {
                if let results = request.results {
                    self.processSegmentationRequest(results, selection)
                }
            })
        })
        segmentationRequests.imageCropAndScaleOption = .scaleFill
        self.segmentationRequests = [segmentationRequests]
        
        let perClassSegmentationRequests = VNCoreMLRequest(model: self.visionModel, completionHandler: {request, error in
            DispatchQueue.main.async(execute: {
                if let results = request.results {
                    self.processPerClassSegmentationRequest(results, selection)
                }
            })
        })
        perClassSegmentationRequests.imageCropAndScaleOption = .scaleFill
        self.perClassSegmentationRequests = [perClassSegmentationRequests]
    }
    
    func processSegmentationRequest(_ observations: [Any], _ selection: [Int]){
        let obs = observations as! [VNPixelBufferObservation]
        if obs.isEmpty{
            print("The Segmentation array is Empty")
            return
        }

        let outPixelBuffer = (obs.first)!
        let (_, selectedIndices) = extractUniqueGrayscaleValues(from: outPixelBuffer.pixelBuffer)
        
        let selectedIndicesSet = Set(selectedIndices)
        let segmentedIndices = selection.filter{ selectedIndicesSet.contains($0) }
        
        // FIXME: Save the pixelBuffer instead of the CIImage into sharedImageData, and convert to CIImage on the fly whenever required
        
        self.masker.inputImage = CIImage(cvPixelBuffer: outPixelBuffer.pixelBuffer)
        
        // TODO: Instead of passing new grayscaleValues and colorValues to the custom CIFilter for every new image
        // Check if you can instead simply pass the constants as the parameters during the filter initialization
        self.masker.grayscaleValues = selection.map { Constants.ClassConstants.grayValues[$0] }
        self.masker.colorValues =  selection.map { Constants.ClassConstants.colors[$0] }
        
        self.segmentedIndices = segmentedIndices
        segmentationResults = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .downMirrored)
//        isSegmentationProcessing = false
    }

    func performSegmentationRequest(with pixelBuffer: CVPixelBuffer) {
//        guard !isSegmentationProcessing else { return }

//        isSegmentationProcessing = true

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform(self.segmentationRequests)
        } catch {
//            self.isSegmentationProcessing = false
            print("Error performing request: \(error.localizedDescription)")
        }
    }
    
    func processPerClassSegmentationRequest(_ observations: [Any], _ selection: [Int]){
        let obs = observations as! [VNPixelBufferObservation]
        if obs.isEmpty{
            print("The Segmentation array is Empty")
            return
        }

        let outPixelBuffer = (obs.first)!
        let (_, selectedIndices) = extractUniqueGrayscaleValues(from: outPixelBuffer.pixelBuffer)
        
        let selectedIndicesSet = Set(selectedIndices)
        let segmentedIndices = selection.filter{ selectedIndicesSet.contains($0) }
        
        self.masker.inputImage = CIImage(cvPixelBuffer: outPixelBuffer.pixelBuffer)
        
        let totalCount = segmentedIndices.count
        var perClassSegmentationResults = [CIImage](repeating: CIImage(), count: totalCount)
        // For each class, extract the separate segment
        for i in segmentedIndices.indices {
            let currentClass = segmentedIndices[i]
            self.masker.grayscaleValues = [Constants.ClassConstants.grayValues[currentClass]]
            self.masker.colorValues = [Constants.ClassConstants.colors[currentClass]]
            perClassSegmentationResults[i] = self.masker.outputImage!
        }
        
        self.perClassSegmentationResults = perClassSegmentationResults
        isPerClassSegmentationProcessing = false
    }
    
    func performPerClassSegmentationRequest(with pixelBuffer: CVPixelBuffer) {
        guard !isPerClassSegmentationProcessing else { return }

        isPerClassSegmentationProcessing = true

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform(self.segmentationRequests)
        } catch {
            self.isPerClassSegmentationProcessing = false
            print("Error performing request: \(error.localizedDescription)")
        }
    }
    
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
        
        let valueToIndex = Dictionary(uniqueKeysWithValues: Constants.ClassConstants.grayValues.enumerated().map { ($0.element, $0.offset) })
        
        // MARK: sorting may not be necessary for our use case
        let selectedIndices = uniqueValues.map { UInt8($0) }
            .map {Float($0) / 255.0 }
            .compactMap { valueToIndex[$0]}
            .sorted()
            
        return (uniqueValues, selectedIndices)
    }
}

// Functions not currently in use
extension SegmentationViewController {
    // Get the grayscale values and the corresponding colors
    func getGrayScaleAndColorsFromSelection(selection: [Int], classes: [String], grayscaleToClassMap: [UInt8: String], grayValues: [Float]) -> ([UInt8], [CIColor]) {
        let selectedClasses = selection.map { classes[$0] }
        var selectedGrayscaleValues: [UInt8] = []
        var selectedColors: [CIColor] = []

        for (key, value) in grayscaleToClassMap {
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
    
    func preprocessPixelBuffer(_ pixelBuffer: CVPixelBuffer, withSelectedGrayscaleValues selectedValues: [UInt8]) {
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
