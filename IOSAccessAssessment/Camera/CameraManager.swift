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
import Vision

class CameraManager: ObservableObject, CaptureDataReceiver {
    
    var sharedImageData: SharedImageData?
    var segmentationModel: SegmentationModel?
    var segmentationPipeline: SegmentationPipeline?

    @Published var isFilteringDepth: Bool {
        didSet {
            controller.isFilteringEnabled = isFilteringDepth
        }
    }
    // TODO: Currently, the orientation is redundant until we start using other orientation types
    //  It does not seem to be used anywhere currently
    @Published var orientation = UIDevice.current.orientation
    @Published var isProcessingCapturedResult = false
    @Published var dataAvailable = false
    
    let controller: CameraController
    var cancellables = Set<AnyCancellable>()
    var session: AVCaptureSession { controller.captureSession }
    
    init(sharedImageData: SharedImageData, segmentationModel: SegmentationModel, segmentationPipeline: SegmentationPipeline) {
        self.sharedImageData = sharedImageData
        self.segmentationModel = segmentationModel
        self.segmentationPipeline = segmentationPipeline
        
        controller = CameraController()
        isFilteringDepth = true
        controller.startStream()
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.orientation = UIDevice.current.orientation
        }.store(in: &cancellables)
        controller.delegate = self
    }
    
    func resumeStream() {
        controller.startStream()
        isProcessingCapturedResult = false
    }
    
    func stopStream() {
        controller.stopStream()
        isProcessingCapturedResult = false
    }
    
    func getLidarAvailability(isLidarAvailable: Bool) {
        self.sharedImageData?.isLidarAvailable = isLidarAvailable
    }
    
    func onNewData(cameraImage: CIImage, depthImage: CIImage?) -> Void {
        DispatchQueue.main.async {
            if !self.isProcessingCapturedResult {
                let previousImage = self.sharedImageData?.cameraImage
                let previousObjects = self.sharedImageData?.objects ?? []
                self.sharedImageData?.cameraImage = cameraImage // UIImage(cgImage: cameraImage, scale: 1.0, orientation: .right)
                self.sharedImageData?.depthImage = depthImage
                
//                self.segmentationModel?.performSegmentationRequest(with: cameraImage)
                self.segmentationPipeline?.processRequest(with: cameraImage, previousImage: previousImage, previousObjects: previousObjects)
                
                if self.dataAvailable == false {
                    self.dataAvailable = true
                }
            }
        }
    }

   
}

