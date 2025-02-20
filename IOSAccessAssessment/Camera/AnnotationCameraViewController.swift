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
    var depthImage: CIImage?
    var cameraView: UIImageView? = nil
    var segmentationView: UIImageView? = nil
    var sharedImageData: SharedImageData?
    
    let annotationCIContext = CIContext()
    let imageSaver = ImageSaver()
    
    var frameRect: CGRect = CGRect()
    
    init(sharedImageData: SharedImageData, index: Int) {
        super.init(nibName: nil, bundle: nil)
        self.cameraImage = UIImage(ciImage: sharedImageData.cameraImage!, scale: 1.0, orientation: .right)
        self.depthImage = sharedImageData.depthImage
//        self.cameraImage = self.convertToGrayScale(image: sharedImageData.cameraImage!)
        self.segmentationImage = sharedImageData.classImages[index]
        
        let cameraCGImage = annotationCIContext.createCGImage(sharedImageData.cameraImage!, from: sharedImageData.cameraImage!.extent)
        let cameraUIImage = UIImage(cgImage: cameraCGImage!, scale: 1.0, orientation: .right)
        imageSaver.writeToPhotoAlbum(image: cameraUIImage)
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
        
        let segmentationCGImage = annotationCIContext.createCGImage(self.segmentationImage!, from: self.segmentationImage!.extent)
        var segmentationUIImage = UIImage(cgImage: segmentationCGImage!, scale: 1.0, orientation: .downMirrored)
        imageSaver.writeToPhotoAlbum(image: segmentationUIImage)
        
//        var segmentationUIImage = UIImage(ciImage: segmentationImage!, scale: 1.0, orientation: .downMirrored)
//        segmentationUIImage = self.convertToGrayScale(image: segmentationImage!)
        segmentationUIImage = performWatershed(maskImage: segmentationImage!, depthImage: depthImage!)
        segmentationView = UIImageView(image: segmentationUIImage)
//        segmentationView = UIImageView(image: UIImage(ciImage: segmentationImage!, scale: 1.0, orientation: .downMirrored))
        segmentationView?.frame = CGRect(x: frameRect.minX, y: frameRect.minY, width: frameRect.width, height: frameRect.height)
        segmentationView?.contentMode = .scaleAspectFill
        if let segmentationView = segmentationView {
            view.addSubview(segmentationView)
        }
        cameraView?.bringSubviewToFront(segmentationView!)
    }
    
    func convertToGrayScale(image: CIImage) -> UIImage {
        let cameraCGImage = annotationCIContext.createCGImage(image, from: image.extent)
        let cameraUIImage = UIImage(cgImage: cameraCGImage!, scale: 1.0, orientation: .downMirrored)
        var cameraGrayUIImage = OpenCVWrapper.grayImageConversion(cameraUIImage)
        // Fix the orientation of cameraGrayUIImage
        cameraGrayUIImage = UIImage(cgImage: cameraGrayUIImage.cgImage!, scale: 1.0, orientation: .downMirrored)
        return cameraGrayUIImage
    }
    
    func performWatershed(maskImage: CIImage, depthImage: CIImage) -> UIImage {
        let maskCGImage = annotationCIContext.createCGImage(maskImage, from: maskImage.extent)
        let maskUIImage = UIImage(cgImage: maskCGImage!, scale: 1.0, orientation: .downMirrored)
        let depthCGImage = annotationCIContext.createCGImage(depthImage, from: depthImage.extent)
        let depthUIImage = UIImage(cgImage: depthCGImage!, scale: 1.0, orientation: .downMirrored)
        
        var instanceSegmentationImage = OpenCVWrapper.performWatershed(maskUIImage, depthUIImage);
        // Update the orientation of the image
        instanceSegmentationImage = UIImage(cgImage: instanceSegmentationImage.cgImage!, scale: 1.0, orientation: .downMirrored)
        return instanceSegmentationImage
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
        uiViewController.cameraImage = UIImage(ciImage: sharedImageData.cameraImage!, scale: 1.0, orientation: .right)
//        uiViewController.cameraImage = uiViewController.convertToGrayScale(image: sharedImageData.cameraImage!)
        uiViewController.segmentationImage = sharedImageData.classImages[index]
        uiViewController.viewDidLoad()
    }
}
