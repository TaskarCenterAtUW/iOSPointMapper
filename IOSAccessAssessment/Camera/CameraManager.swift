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

    @Published var isFilteringDepth: Bool {
        didSet {
            controller.isFilteringEnabled = isFilteringDepth
        }
    }
    // TODO: Currently, the orientation is redundant until we start using other orientation types
    //  It does not seem to be used anywhere currently
    @Published var orientation = UIDevice.current.orientation
    @Published var processingCapturedResult = false
    @Published var dataAvailable = false
    
    let controller: CameraController
    var cancellables = Set<AnyCancellable>()
    var session: AVCaptureSession { controller.captureSession }
    
    init(sharedImageData: SharedImageData, segmentationModel: SegmentationModel) {
        self.sharedImageData = sharedImageData
        self.segmentationModel = segmentationModel
        
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
        processingCapturedResult = false
    }
    
    func stopStream() {
        controller.stopStream()
        processingCapturedResult = false
    }
    
    func onNewData(cameraImage: CIImage, depthPixelBuffer: CVPixelBuffer) -> Void {
        DispatchQueue.main.async {
            if !self.processingCapturedResult {
                self.sharedImageData?.cameraImage = cameraImage // UIImage(cgImage: cameraImage, scale: 1.0, orientation: .right)
//                self.sharedImageData?.appendFrame(frame: cameraImage)
                self.sharedImageData?.depthData = depthPixelBuffer
                
                self.segmentationModel?.performSegmentationRequest(with: cameraImage)
                
                if self.dataAvailable == false {
                    self.dataAvailable = true
                }
            }
        }
    }

   
}

