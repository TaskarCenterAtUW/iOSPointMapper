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

//    var capturedData: CameraCapturedData
    @Published var isFilteringDepth: Bool {
        didSet {
            controller.isFilteringEnabled = isFilteringDepth
        }
    }
    @Published var orientation = UIDevice.current.orientation
    @Published var waitingForCapture = false
    @Published var processingCapturedResult = false
    @Published var dataAvailable = false
    @Published var sharedImageData: SharedImageData?
    
    let controller: CameraController
    var cancellables = Set<AnyCancellable>()
    var session: AVCaptureSession { controller.captureSession }
    
    init(sharedImageData: SharedImageData) {
        // Create an object to store the captured data for the views to present.
//        capturedData = CameraCapturedData()
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
        waitingForCapture = true
    }
    
    func resumeStream() {
        controller.startStream()
        processingCapturedResult = false
        waitingForCapture = false
    }
    
    func onNewPhotoData() {
        // Because the views hold a reference to `capturedData`, the app updates each texture separately.
//        self.capturedData.depth = capturedData.depth
//        self.capturedData.colorY = capturedData.colorY
//        self.capturedData.colorCbCr = capturedData.colorCbCr
//        self.capturedData.cameraIntrinsics = capturedData.cameraIntrinsics
//        self.capturedData.cameraReferenceDimensions = capturedData.cameraReferenceDimensions
        waitingForCapture = false
        processingCapturedResult = true
    }
    
    func onNewData(pixelBuffer: CVPixelBuffer) {
        DispatchQueue.main.async {
            if !self.processingCapturedResult {
//                // Because the views hold a reference to `capturedData`, the app updates each texture separately.
//                self.capturedData.depth = capturedData.depth
//                self.capturedData.colorY = capturedData.colorY
//                self.capturedData.colorCbCr = capturedData.colorCbCr
//                self.capturedData.cameraIntrinsics = capturedData.cameraIntrinsics
//                self.capturedData.cameraReferenceDimensions = capturedData.cameraReferenceDimensions
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

class CameraCapturedData {
    
    var depth: MTLTexture?
    var colorY: MTLTexture?
    var colorCbCr: MTLTexture?
    var cameraIntrinsics: matrix_float3x3
    var cameraReferenceDimensions: CGSize

    init(depth: MTLTexture? = nil,
         colorY: MTLTexture? = nil,
         colorCbCr: MTLTexture? = nil,
         cameraIntrinsics: matrix_float3x3 = matrix_float3x3(),
         cameraReferenceDimensions: CGSize = .zero) {
        
        self.depth = depth
        self.colorY = colorY
        self.colorCbCr = colorCbCr
        self.cameraIntrinsics = cameraIntrinsics
        self.cameraReferenceDimensions = cameraReferenceDimensions
    }
}

