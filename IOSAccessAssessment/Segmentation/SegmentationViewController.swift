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
    }
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

