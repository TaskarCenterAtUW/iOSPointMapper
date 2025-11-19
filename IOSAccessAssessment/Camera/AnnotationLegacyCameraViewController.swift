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
class AnnotationLegacyCameraViewController: UIViewController {
    var cameraImage: UIImage?
    var segmentationImage: UIImage?
    var objectsImage: UIImage?
    
    var cameraView: UIImageView? = nil
    var segmentationView: UIImageView? = nil
    var objectsView: UIImageView? = nil
    
    var sharedImageData: SharedImageData?
    
    init(cameraImage: UIImage, segmentationImage: UIImage, objectsImage: UIImage) {
        self.cameraView = UIImageView()
        self.segmentationView = UIImageView()
        self.objectsView = UIImageView()
        
        self.cameraImage = cameraImage
        self.segmentationImage = segmentationImage
        self.objectsImage = objectsImage
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        cameraView?.contentMode = .scaleAspectFill
        cameraView?.translatesAutoresizingMaskIntoConstraints = false
        cameraView?.image = cameraImage
        if let cameraView = cameraView {
            view.addSubview(cameraView)
        }
        
        segmentationView?.contentMode = .scaleAspectFill
        segmentationView?.translatesAutoresizingMaskIntoConstraints = false
        segmentationView?.image = segmentationImage
        if let segmentationView = segmentationView {
            view.addSubview(segmentationView)
        }
        
        objectsView?.contentMode = .scaleAspectFill
        objectsView?.translatesAutoresizingMaskIntoConstraints = false
        objectsView?.image = objectsImage
        if let objectsView = objectsView {
            view.addSubview(objectsView)
        }
        
        if let cameraView = cameraView {
            NSLayoutConstraint.activate([
                cameraView.topAnchor.constraint(equalTo: view.topAnchor),
                cameraView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                cameraView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                cameraView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//                cameraView.widthAnchor.constraint(equalTo: cameraView.heightAnchor, multiplier: aspectRatio)
            ])
        }
        
        if let segmentationView = segmentationView {
            NSLayoutConstraint.activate([
                segmentationView.topAnchor.constraint(equalTo: view.topAnchor),
                segmentationView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                segmentationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                segmentationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//                segmentationView.widthAnchor.constraint(equalTo: segmentationView.heightAnchor, multiplier: aspectRatio)
            ])
        }
        
        if let objectsView = objectsView {
            NSLayoutConstraint.activate([
                objectsView.topAnchor.constraint(equalTo: view.topAnchor),
                objectsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                objectsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                objectsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//                objectsView.widthAnchor.constraint(equalTo: objectsView.heightAnchor, multiplier: aspectRatio)
            ])
        }
        
        cameraView?.bringSubviewToFront(segmentationView!)
        segmentationView?.bringSubviewToFront(objectsView!)
    }
    
    private var aspectRatio: CGFloat {
        guard let image = cameraImage else { return 1.0 }
        return image.size.width / image.size.height
    }
}

struct HostedAnnotationLegacyCameraViewController: UIViewControllerRepresentable{
    let cameraImage: UIImage
    let segmentationImage: UIImage
    let objectsImage: UIImage
    
    func makeUIViewController(context: Context) -> AnnotationLegacyCameraViewController {
        let viewController = AnnotationLegacyCameraViewController(
            cameraImage: cameraImage,
            segmentationImage: segmentationImage,
            objectsImage: objectsImage
        )
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: AnnotationLegacyCameraViewController, context: Context) {
        uiViewController.cameraImage = cameraImage
        uiViewController.segmentationImage = segmentationImage
        uiViewController.objectsImage = objectsImage
        uiViewController.viewDidLoad()
    }
}
