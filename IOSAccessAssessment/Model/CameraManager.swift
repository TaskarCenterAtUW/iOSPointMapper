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
        controller.isFilteringEnabled = true
        controller.startStream()
        isFilteringDepth = controller.isFilteringEnabled
        
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification).sink { _ in
            self.orientation = UIDevice.current.orientation
        }.store(in: &cancellables)
        controller.delegate = self
    }
    
    func startPhotoCapture() {
        controller.capturePhoto()
    }
    
    func resumeStream() {
        controller.startStream()
        processingCapturedResult = false
    }
    
    func onNewPhotoData() {
        processingCapturedResult = true
    }
    
    func onNewData(pixelBuffer: CVPixelBuffer) {
        DispatchQueue.main.async {
            if !self.processingCapturedResult {
                let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                DispatchQueue.main.async {
                    self.sharedImageData?.cameraImage = UIImage(ciImage: ciImage, scale: 1.0, orientation: .right)
                }
                print("A")
                if self.dataAvailable == false {
                    self.dataAvailable = true
                }
            }
        }
    }

   
}

