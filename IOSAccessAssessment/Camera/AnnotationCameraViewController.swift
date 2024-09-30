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
        cameraView = UIImageView(image: cameraImage)
        cameraView?.frame = getFrame()
        cameraView?.contentMode = .scaleAspectFill
        if let cameraView = cameraView {
            view.addSubview(cameraView)
        }
        
        segmentationView = UIImageView(image: UIImage(ciImage: segmentationImage!, scale: 1.0, orientation: .downMirrored))
        segmentationView?.frame = getFrame()
        segmentationView?.contentMode = .scaleAspectFill
        if let segmentationView = segmentationView {
            view.addSubview(segmentationView)
        }
        cameraView?.bringSubviewToFront(segmentationView!)
    }
    
    // FIXME: Frame Details should ideally come from the Parent that is calling this ViewController. Try GeometryReader
    private func getFrame() -> CGRect {
        let screenSize = UIScreen.main.bounds
        let screenWidth = screenSize.width
        let screenHeight = screenSize.height
        
        // Currently, the app only supports portrait mode
        // Hence, we can set the size of the square frame relative to screen width
        // with the screen height acting as a threshold to support other frames and buttons
        // FIXME: Make this logic more robust to screen orientation
        //  so that we can eventually use other orientations
        let sideLength = min(screenWidth * 0.95, screenHeight * 0.40)
        
        let xPosition = (screenWidth - sideLength) / 2
        
        return CGRect(x: xPosition, y: 0, width: sideLength, height: sideLength)
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
