//
//  AnnotationCameraViewController.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/26/24.
//

import SwiftUI

class AnnotationCameraViewController: UIViewController {
    var cameraImage: UIImage?
    var segmentationImage: CIImage?
    var cameraView: UIImageView? = nil
    var segmentationView: UIImageView? = nil
    var sharedImageData: SharedImageData?
    
    init(sharedImageData: SharedImageData, index: Int) {
        self.cameraImage = sharedImageData.cameraImage
        self.segmentationImage = sharedImageData.classImages[index]
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let centerX = (UIScreen.main.bounds.width - 256.0) / 2.0
        cameraView = UIImageView(image: cameraImage)
        cameraView?.frame = CGRect(x: centerX, y: 0.0, width: 256.0, height: 256.0)
        cameraView?.contentMode = .scaleAspectFill
        if let cameraView = cameraView {
            view.addSubview(cameraView)
        }
        
        segmentationView = UIImageView(image: UIImage(ciImage: segmentationImage!, scale: 1.0, orientation: .downMirrored))
        segmentationView?.frame = CGRect(x: centerX, y: 0.0, width: 256.0, height: 256.0)
        segmentationView?.contentMode = .scaleAspectFill
        if let segmentationView = segmentationView {
            view.addSubview(segmentationView)
        }
        cameraView?.bringSubviewToFront(segmentationView!)
    }
}

struct HostedAnnotationCameraViewController: UIViewControllerRepresentable{
//    var cameraImage: UIImage
//    var segmentationImage: UIImage
    let sharedImageData: SharedImageData
    let index: Int
    
    func makeUIViewController(context: Context) -> AnnotationCameraViewController {
        return AnnotationCameraViewController(sharedImageData: sharedImageData, index: index)
    }
    
    func updateUIViewController(_ uiViewController: AnnotationCameraViewController, context: Context) {
        uiViewController.cameraImage = sharedImageData.cameraImage
        uiViewController.segmentationImage = sharedImageData.classImages[index]
//        uiViewController.cameraImage = cameraImage
//        uiViewController.segmentationImage = segmentationImage
        uiViewController.viewDidLoad()
    }
}
