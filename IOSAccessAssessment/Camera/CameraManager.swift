//
//  CameraManager.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import Foundation
import SwiftUI
import Combine
import simd
import AVFoundation

enum CameraManagerError: Error, LocalizedError {
    case pixelBufferPoolCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .pixelBufferPoolCreationFailed:
            return "Failed to create pixel buffer pool."
        }
    }
}

/**
    CameraManager is responsible for managing the camera stream and processing the captured frames.
 */
class CameraManager: ObservableObject, CaptureDataReceiver {
    
    var sharedImageData: SharedImageData?
    var segmentationPipeline: SegmentationPipeline?

    @Published var isFilteringDepth: Bool {
        didSet {
            controller.isFilteringEnabled = isFilteringDepth
        }
    }
    
    @Published var deviceOrientation = UIDevice.current.orientation {
        didSet {
//            print("Orientation changed to \(deviceOrientation)")
        }
    }
    @Published var isProcessingCapturedResult = false
    @Published var dataAvailable = false
    
    // Temporary image data
    @Published var cameraUIImage: UIImage?
    @Published var depthUIImage: UIImage?
    
    let controller: CameraController
    var cancellables = Set<AnyCancellable>()
    var session: AVCaptureSession { controller.captureSession }
    
    var ciContext = CIContext(options: nil)
    var cameraPixelBufferPool: CVPixelBufferPool? = nil
    var cameraColorSpace: CGColorSpace? = nil
    var depthPixelBufferPool: CVPixelBufferPool? = nil
    var depthColorSpace: CGColorSpace? = nil
    
    init(sharedImageData: SharedImageData, segmentationPipeline: SegmentationPipeline) {
        self.sharedImageData = sharedImageData
        self.segmentationPipeline = segmentationPipeline
        
        controller = CameraController()
        isFilteringDepth = true
        controller.startStream()
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.deviceOrientation = UIDevice.current.orientation
        }.store(in: &cancellables)
        controller.delegate = self
        
        do {
            try setUpPixelBufferPools()
        } catch {
            fatalError("Failed to set up pixel buffer pools: \(error.localizedDescription)")
        }
    }
    
    func resumeStream() {
        controller.startStream()
        isProcessingCapturedResult = false
    }
    
    func stopStream() {
        controller.stopStream()
        isProcessingCapturedResult = false
    }
    
    func onNewData(cameraPixelBuffer: CVPixelBuffer, depthPixelBuffer: CVPixelBuffer?) {
        let cameraImage = self.orientAndFixCameraFrame(cameraPixelBuffer)
        let depthImage = self.isFilteringDepth ? self.orientAndFixDepthFrame(depthPixelBuffer!) : nil
        DispatchQueue.main.async {
            if self.isProcessingCapturedResult {
                return
            }
            let previousImage = self.sharedImageData?.cameraImage
            self.sharedImageData?.cameraImage = cameraImage // UIImage(cgImage: cameraImage, scale: 1.0, orientation: .right)
            self.sharedImageData?.depthImage = depthImage
            
            self.cameraUIImage = UIImage(ciImage: cameraImage)
            self.depthUIImage = UIImage(ciImage: depthImage!)
            
            self.segmentationPipeline?.processRequest(with: cameraImage, previousImage: previousImage,
                                                      deviceOrientation: self.deviceOrientation)
            
            if self.dataAvailable == false {
                self.dataAvailable = true
            }
        }
    }
}

// Functions to orient and fix the camera and depth frames
extension CameraManager {
    func setUpPixelBufferPools() throws {
        // Set up the pixel buffer pool for future flattening of camera images
        let cameraPixelBufferPoolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 5
        ]
        let cameraPixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Constants.SelectedSegmentationConfig.inputSize.width,
            kCVPixelBufferHeightKey as String: Constants.SelectedSegmentationConfig.inputSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let cameraStatus = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            cameraPixelBufferPoolAttributes as CFDictionary,
            cameraPixelBufferAttributes as CFDictionary,
            &cameraPixelBufferPool
        )
        guard cameraStatus == kCVReturnSuccess else {
            throw CameraManagerError.pixelBufferPoolCreationFailed
        }
        cameraColorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Set up the pixel buffer pool for depth images
        let depthPixelBufferPoolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 5
        ]
        let depthPixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_DepthFloat32,
            kCVPixelBufferWidthKey as String: Constants.SelectedSegmentationConfig.inputSize.width,
            kCVPixelBufferHeightKey as String: Constants.SelectedSegmentationConfig.inputSize.height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let depthStatus = CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            depthPixelBufferPoolAttributes as CFDictionary,
            depthPixelBufferAttributes as CFDictionary,
            &depthPixelBufferPool
        )
        guard depthStatus == kCVReturnSuccess else {
            throw CameraManagerError.pixelBufferPoolCreationFailed
        }
        depthColorSpace = nil
    }
    
    func orientAndFixCameraFrame(_ frame: CVPixelBuffer) -> CIImage {
        let croppedSize: CGSize = CGSize(
            width: Constants.SelectedSegmentationConfig.inputSize.width,
            height: Constants.SelectedSegmentationConfig.inputSize.height
        )
        var cameraImage = CIImage(cvPixelBuffer: frame)
        cameraImage = CIImageUtils.resizeWithAspectThenCrop(cameraImage, to: croppedSize)
        cameraImage = cameraImage.oriented(
            CameraOrientation.getCGImageOrientationForBackCamera(currentDeviceOrientation: self.deviceOrientation)
        )
        let renderedCameraPixelBuffer = renderCIImageToPixelBuffer(
            cameraImage,
            size: croppedSize,
            pixelBufferPool: cameraPixelBufferPool!,
            colorSpace: cameraColorSpace
        )
        return renderedCameraPixelBuffer != nil ? CIImage(cvPixelBuffer: renderedCameraPixelBuffer!) : cameraImage
    }
    
    func orientAndFixDepthFrame(_ frame: CVPixelBuffer) -> CIImage {
        let croppedSize: CGSize = CGSize(
            width: Constants.SelectedSegmentationConfig.inputSize.width,
            height: Constants.SelectedSegmentationConfig.inputSize.height
        )
        
        var depthImage = CIImage(cvPixelBuffer: frame)
        depthImage = CIImageUtils.resizeWithAspectThenCrop(depthImage, to: croppedSize)
        depthImage = depthImage.oriented(
            CameraOrientation.getCGImageOrientationForBackCamera(currentDeviceOrientation: self.deviceOrientation)
        )
        let depthPixelBuffer = renderCIImageToPixelBuffer(
            depthImage,
            size: croppedSize,
            pixelBufferPool: depthPixelBufferPool!,
            colorSpace: depthColorSpace
        )
        return depthPixelBuffer != nil ? CIImage(cvPixelBuffer: depthPixelBuffer!) : depthImage
    }
    
    private func renderCIImageToPixelBuffer(
        _ image: CIImage, size: CGSize,
        pixelBufferPool: CVPixelBufferPool, colorSpace: CGColorSpace? = nil) -> CVPixelBuffer? {
        var pixelBufferOut: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBufferOut)
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut else {
            return nil
        }
        
        ciContext.render(image, to: pixelBuffer, bounds: CGRect(origin: .zero, size: size), colorSpace: colorSpace)
        return pixelBuffer
    }
}
