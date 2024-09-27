//
//  CameraViewController.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/26/24.
//

import SwiftUI
import AVFoundation

class CameraViewController: UIViewController {
    var session: AVCaptureSession?
    var rootLayer: CALayer! = nil
    private var previewLayer: AVCaptureVideoPreviewLayer! = nil
//    var detectionLayer: CALayer! = nil
//    var detectionView: UIImageView! = nil
    
    init(session: AVCaptureSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setUp(session: session!)
    }
    
    private func setUp(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = getFrame()
//        previewLayer.borderWidth = 2.0
//        previewLayer.borderColor = UIColor.blue.cgColor
//
//        detectionView = UIImageView()
//        detectionView.frame = CGRect(x: 59, y: 366, width: 280, height: 280)
//        detectionView.transform = CGAffineTransform(rotationAngle: -.pi / 2)
//        detectionView.layer.borderWidth = 2.0
//        detectionView.layer.borderColor = UIColor.blue.cgColor
        
        DispatchQueue.main.async { [weak self] in
            self!.view.layer.addSublayer(self!.previewLayer)
            //self!.view.layer.addSublayer(self!.detectionLayer)
        }
    }
    
    private func getFrame() -> CGRect {
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        
        let minSideLength = min(screenWidth, screenHeight)
        let maxSideLength = max(screenWidth, screenHeight)
        let xPosition = (screenWidth - sideLength) / 2
        
        return CGRect(x: xPosition, y: 0, width: sideLength, height: sideLength)
    }
}

struct HostedCameraViewController: UIViewControllerRepresentable{
    var session: AVCaptureSession!
    
    func makeUIViewController(context: Context) -> CameraViewController {
        annotationView = false
        return CameraViewController(session: session)
    }
    
    func updateUIViewController(_ uiView: CameraViewController, context: Context) {
    }
}
