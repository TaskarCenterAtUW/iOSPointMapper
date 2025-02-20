//
//  AnnotationCameraViewController.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/26/24.
//

import SwiftUI

/**
    A view controller that displays the camera image and the segmentation image for user feedback and annotation.
 */
class AnnotationCameraViewController: UIViewController {
    var cameraImage: UIImage?
    var segmentationImage: UIImage?
    var cameraView: UIImageView? = nil
    var segmentationView: UIImageView? = nil
    var sharedImageData: SharedImageData?
    
    var frameRect: CGRect = CGRect()
    
    init(cameraImage: UIImage, segmentationImage: UIImage) {
        self.cameraImage = cameraImage
        self.segmentationImage = segmentationImage
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
        
        segmentationView = UIImageView(image: segmentationImage)
        segmentationView?.frame = CGRect(x: frameRect.minX, y: frameRect.minY, width: frameRect.width, height: frameRect.height)
        segmentationView?.contentMode = .scaleAspectFill
        if let segmentationView = segmentationView {
            view.addSubview(segmentationView)
        }
        cameraView?.bringSubviewToFront(segmentationView!)
    }
}

struct HostedAnnotationCameraViewController: UIViewControllerRepresentable{
    let cameraImage: UIImage
    let segmentationImage: UIImage
    var frameRect: CGRect
    
    func makeUIViewController(context: Context) -> AnnotationCameraViewController {
        let viewController = AnnotationCameraViewController(cameraImage: cameraImage, segmentationImage: segmentationImage)
        viewController.frameRect = frameRect
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: AnnotationCameraViewController, context: Context) {
        uiViewController.cameraImage = cameraImage
        uiViewController.segmentationImage = segmentationImage
        uiViewController.viewDidLoad()
    }
}
