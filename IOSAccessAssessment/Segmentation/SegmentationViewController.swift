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
    
    var segmentationImage: UIImage?
    
    var frameRect: CGRect = CGRect()
    var selection:[Int] = []
    var classes: [String] = []
    
//    var grayscaleValues: [Float]  {
//        return self.selection.map { Constants.ClassConstants.grayValues[$0] }
//    }
//    var colorValues: [CIColor] {
//        return self.selection.map { Constants.ClassConstants.colors[$0] }
//    }
//    static var requests = [VNRequest]()
    
    // TODO: Check if replacing the custom CIFilter with a plain class would help improve performance.
    //  We are not chaining additional filters, thus using CIFilter doesn't seem to make much sense.
//    let masker = GrayscaleToColorCIFilter()
    
    init(segmentationImage: UIImage?) {
        self.segmentationView = UIImageView()
        self.segmentationImage = segmentationImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        segmentationView.frame = self.frameRect
        segmentationView.contentMode = .scaleAspectFill
        self.view.addSubview(segmentationView)
        self.segmentationView.image = self.segmentationImage
//        self.setupVisionModel()
    }
    
//    private func setupVisionModel() {
//        let modelURL = Bundle.main.url(forResource: "deeplabv3plus_mobilenet", withExtension: "mlmodelc")
//        guard let visionModel = try? VNCoreMLModel(for: MLModel(contentsOf: modelURL!)) else {
//            fatalError("Can not load CNN model")
//        }
//
//        let segmentationRequest = VNCoreMLRequest(model: visionModel, completionHandler: {request, error in
//            DispatchQueue.main.async(execute: {
//                if let results = request.results {
//                    self.processSegmentationRequest(results)
//                }
//            })
//        })
//        segmentationRequest.imageCropAndScaleOption = .scaleFill
//        SegmentationViewController.requests = [segmentationRequest]
//    }
    
//    func processSegmentationRequest(_ observations: [Any]){
//        let obs = observations as! [VNPixelBufferObservation]
//        if obs.isEmpty{
//            print("The Segmentation array is Empty")
//            return
//        }
//
//        let outPixelBuffer = (obs.first)!
//        let (_, selectedIndices) = extractUniqueGrayscaleValues(from: outPixelBuffer.pixelBuffer)
//        
//        let selectedIndicesSet = Set(selectedIndices)
//        let segmentedIndices = self.selection.filter{ selectedIndicesSet.contains($0) }
//        self.sharedImageData?.segmentedIndices = segmentedIndices
//        
//        // FIXME: Save the pixelBuffer instead of the CIImage into sharedImageData, and convert to CIImage on the fly whenever required
//        
//        self.masker.inputImage = CIImage(cvPixelBuffer: outPixelBuffer.pixelBuffer)
//        
//        processSegmentationRequestPerClass()
//        // TODO: Instead of passing new grayscaleValues and colorValues to the custom CIFilter for every new image
//        // Check if you can instead simply pass the constants as the parameters during the filter initialization
//        self.masker.grayscaleValues = self.grayscaleValues
//        self.masker.colorValues =  self.colorValues
//        self.segmentationView.image = UIImage(ciImage: self.masker.outputImage!, scale: 1.0, orientation: .downMirrored)
//    }
    
    // Generate segmentation image for each class
//    func processSegmentationRequestPerClass() {
//        guard let segmentedIndices = self.sharedImageData?.segmentedIndices else {
//            return
//        }
//        
//        let totalCount = segmentedIndices.count
//        self.sharedImageData?.classImages = [CIImage](repeating: CIImage(), count: totalCount)
//        // For each class, extract the separate segment
//        for i in segmentedIndices.indices {
//            let currentClass = segmentedIndices[i]
////            self.masker.inputImage = self.sharedImageData?.pixelBuffer // No need to set this every time
//            self.masker.grayscaleValues = [Constants.ClassConstants.grayValues[currentClass]]
//            self.masker.colorValues = [Constants.ClassConstants.colors[currentClass]]
//            self.sharedImageData?.classImages[i] = self.masker.outputImage!
//        }
//    }
}

// Image Processing Functions
extension SegmentationViewController {
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
        
        // MARK: sorting may not be necessary for our use case
        let selectedIndices = uniqueValues.map { UInt8($0) }
            .map {Float($0) / 255.0 }
            .compactMap { valueToIndex[$0]}
            .sorted()
            
        return (uniqueValues, selectedIndices)
    }
}

struct HostedSegmentationViewController: UIViewControllerRepresentable{
    @Binding var segmentationImage: UIImage?
    var frameRect: CGRect
    
    func makeUIViewController(context: Context) -> SegmentationViewController {
        let viewController = SegmentationViewController(segmentationImage: segmentationImage)
        viewController.frameRect = frameRect
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: SegmentationViewController, context: Context) {
        uiViewController.segmentationView.image = segmentationImage
    }
}

