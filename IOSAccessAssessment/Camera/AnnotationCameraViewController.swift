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
    
    var frameRect: CGRect = CGRect()
    
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
        cameraView = UIImageView(image: cameraImage)
        cameraView?.frame = CGRect(x: frameRect.minX, y: frameRect.minY, width: frameRect.width, height: frameRect.height)
        cameraView?.contentMode = .scaleAspectFill
        if let cameraView = cameraView {
            view.addSubview(cameraView)
        }
        
        segmentationView = UIImageView(image: UIImage(ciImage: segmentationImage!, scale: 1.0, orientation: .downMirrored))
        segmentationView?.frame = CGRect(x: frameRect.minX, y: frameRect.minY, width: frameRect.width, height: frameRect.height)
        segmentationView?.contentMode = .scaleAspectFill
        if let segmentationView = segmentationView {
            view.addSubview(segmentationView)
        }
        cameraView?.bringSubviewToFront(segmentationView!)
    }
}

struct HostedAnnotationCameraViewController: UIViewControllerRepresentable{
    @EnvironmentObject var sharedImageData: SharedImageData
    let index: Int
    var frameRect: CGRect
    
    func makeUIViewController(context: Context) -> AnnotationCameraViewController {
        let viewController = AnnotationCameraViewController(sharedImageData: sharedImageData, index: index)
        viewController.frameRect = frameRect
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: AnnotationCameraViewController, context: Context) {
        uiViewController.cameraImage = sharedImageData.cameraImage
        uiViewController.segmentationImage = sharedImageData.classImages[index]
        uiViewController.viewDidLoad()
    }
}
