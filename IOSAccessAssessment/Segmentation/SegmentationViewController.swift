//
//  SegmentationViewController.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/26/24.
//

import SwiftUI
import AVFoundation
import Vision
import Metal
import CoreImage
import MetalKit


class SegmentationViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var segmentationView: UIImageView! = nil
    var sharedImageData: SharedImageData?
    var selection:[Int] = []
    var classes: [String] = []
//    var grayscaleValue:Float = 180 / 255.0
//    var singleColor:CIColor = CIColor(red: 0.0, green: 0.5, blue: 0.5)
    
    static var requests = [VNRequest]()
    
    // define the filter that will convert the grayscale prediction to color image
    //let masker = ColorMasker()
    let masker = CustomCIFilter()
    
    init(sharedImageData: SharedImageData) {
        self.segmentationView = UIImageView()
        self.sharedImageData = sharedImageData
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        segmentationView.frame = getFrame()
        segmentationView.contentMode = .scaleAspectFill
        self.view.addSubview(segmentationView)
        self.setupVisionModel()
    }
    
    private func setupVisionModel() {
        let modelURL = Bundle.main.url(forResource: "espnetv2_pascal_256", withExtension: "mlmodelc")
        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
            fatalError("Can not load CNN model")
        }

        let segmentationRequest = VNCoreMLRequest(model: visionModel, completionHandler: {request, error in
            DispatchQueue.main.async(execute: {
                if let results = request.results {
                    self.processSegmentationRequest(results)
                }
            })
        })
        segmentationRequest.imageCropAndScaleOption = .scaleFill
        SegmentationViewController.requests = [segmentationRequest]
    }
    
    // TODO: This function is redundant. Should move it to a global function eventually with the appropriate arguments
    private func getFrame() -> CGRect {
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        
        // Currently, the app only supports portrait mode
        // Hence, we can set the size of the square frame relative to screen width
        // with the screen height acting as a threshold to support other frames and buttons
        let sideLength = min(screenWidth * 0.95, screenHeight * 0.40)
        
        let xPosition = (screenWidth - sideLength) / 2
        
        return CGRect(x: xPosition, y: sideLength, width: sideLength, height: sideLength)
    }
    
    func processSegmentationRequest(_ observations: [Any]){
        
        let obs = observations as! [VNPixelBufferObservation]
        if obs.isEmpty{
            print("Empty")
            return
        }

        let outPixelBuffer = (obs.first)!
//        let segMaskGray = outPixelBuffer.pixelBuffer
//        let selectedGrayscaleValues: [UInt8] = [12, 36, 48, 84, 96, 108, 132, 144, 180, 216, 228, 240]
//        let (selectedGrayscaleValues, selectedColors) = convertSelectionToGrayscaleValues(selection: selection, classes: classes, grayscaleMap: Constants.ClassConstants.grayscaleToClassMap, grayValues: Constants.ClassConstants.grayValues)
        let (uniqueGrayscaleValues, selectedIndices) = extractUniqueGrayscaleValues(from: outPixelBuffer.pixelBuffer)
        
        self.sharedImageData?.segmentedIndices = selectedIndices
        // FIXME: Save the pixelBuffer instead of the CIImage into sharedImageData, and convert to CIImage on the fly whenever required
        let ciImage = CIImage(cvPixelBuffer: outPixelBuffer.pixelBuffer)
        self.sharedImageData?.pixelBuffer = ciImage
        //pass through the filter that converts grayscale image to different shades of red
        self.masker.inputImage = ciImage
        
        // TODO: Check why do we need to set the segmentationView.image again after running processSegmentationRequestPerClass
        processSegmentationRequestPerClass()
        self.masker.grayscaleValues = Constants.ClassConstants.grayValues
        self.masker.colorValues =  Constants.ClassConstants.colors
        self.segmentationView.image = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .downMirrored)
        //self.masker.count = 12
    }
    
    // Generate segmentation image for each class
    func processSegmentationRequestPerClass() {
        guard let segmentedIndices = self.sharedImageData?.segmentedIndices else {
            return
        }
        
        // Initialize an array of classImages
        let totalCount = segmentedIndices.count
        self.sharedImageData?.classImages = [CIImage](repeating: CIImage(), count: totalCount)
        // For each class, extract the separate segment
        for i in segmentedIndices.indices {
            let currentClass = segmentedIndices[i]
            self.masker.inputImage = self.sharedImageData?.pixelBuffer
            self.masker.grayscaleValues = [Constants.ClassConstants.grayValues[currentClass]]
            self.masker.colorValues = [Constants.ClassConstants.colors[currentClass]]
            self.segmentationView.image = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .downMirrored)
            self.sharedImageData?.classImages[i] = self.masker.outputImage!
//                self.sharedImageData?.classImages[i] = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .downMirrored)
        }
    }
    
    func convertSelectionToGrayscaleValues(selection: [Int], classes: [String], grayscaleMap: [UInt8: String], grayValues: [Float]) -> ([UInt8], [CIColor]) {
        let selectedClasses = selection.map { classes[$0] }
        var selectedGrayscaleValues: [UInt8] = []
        var selectedColors: [CIColor] = []

        for (key, value) in grayscaleMap {
            if selectedClasses.contains(value) {
                selectedGrayscaleValues.append(key)
                // Assuming grayValues contains grayscale/255, find the index of the grayscale value that matches the key
                if let index = grayValues.firstIndex(of: Float(key)) {
                    selectedColors.append(Constants.ClassConstants.colors[index])
                    // Fetch corresponding color using the same index
                }
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
                    pixel.storeBytes(of: 0, as: UInt8.self) // Setting unselected values to 0
                }
            }
        }

        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }

    
    
    func extractUniqueGrayscaleValues(from pixelBuffer: CVPixelBuffer) -> (Set<UInt8>, [Int]) {
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
        
        let selectedIndices = uniqueValues.map { UInt8($0) }
            .map {Float($0) / 255.0 }
            .compactMap { valueToIndex[$0]}
            .sorted()
            
        return (uniqueValues, selectedIndices)
    }
}

struct HostedSegmentationViewController: UIViewControllerRepresentable{
    var sharedImageData: SharedImageData
    var selection:[Int]
    var classes: [String]
    
    func makeUIViewController(context: Context) -> SegmentationViewController {
        let viewController = SegmentationViewController(sharedImageData: sharedImageData)
//        viewController.sharedImageData = sharedImageData
        viewController.selection = selection
        viewController.classes = classes
        return viewController
    }
    
    func updateUIViewController(_ uiView: SegmentationViewController, context: Context) {
    }
}

