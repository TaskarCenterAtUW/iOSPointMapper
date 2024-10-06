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

class CameraManager: ObservableObject, CaptureDataReceiver {

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
    @Published var sharedImageData: SharedImageData?
    
    let controller: CameraController
    var cancellables = Set<AnyCancellable>()
    var session: AVCaptureSession { controller.captureSession }
    
    init(sharedImageData: SharedImageData) {
        
        self.sharedImageData = sharedImageData
        controller = CameraController()
        isFilteringDepth = true
        controller.startStream()
//        isFilteringDepth = controller.isFilteringEnabled
        
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
    
    func onNewData(cgImage: CGImage, cvPixel: CVPixelBuffer) {
        DispatchQueue.main.async {
            if !self.processingCapturedResult {
                // TODO: Check if the reason the cameraImage and depthData are being set synchronously
                // is the AVCaptureDataOutputSynchronizer
                self.sharedImageData?.cameraImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
                self.sharedImageData?.depthData = cvPixel
//                let context = CIContext()
//                let ciImage = CIImage(cvPixelBuffer: cvPixel)
//                guard let depthCGImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
//                self.sharedImageData?.depthDataImage = UIImage(cgImage: depthCGImage, scale: 1.0, orientation: .right)
                if self.dataAvailable == false {
                    self.dataAvailable = true
                }
            }
        }
    }

   
}

