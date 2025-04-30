//
//  SegmentationViewController.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/26/24.
//

import SwiftUI
import AVFoundation
import Vision
import Metal
import CoreImage
import MetalKit


class SegmentationViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var segmentationView: UIImageView! = nil
    
    var segmentationImage: UIImage?
    
    var frameRect: CGRect = CGRect()
    var selection:[Int] = []
    var classes: [String] = []
    
    init(segmentationImage: UIImage?) {
        self.segmentationView = UIImageView()
        self.segmentationImage = segmentationImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        segmentationView.frame = self.frameRect
        segmentationView.contentMode = .scaleAspectFill
        self.view.addSubview(segmentationView)
        self.segmentationView.image = self.segmentationImage
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        segmentationView.frame = view.bounds
    }
}

struct HostedSegmentationViewController: UIViewControllerRepresentable{
    @Binding var segmentationImage: UIImage?
    var frameRect: CGRect
    
    func makeUIViewController(context: Context) -> SegmentationViewController {
        let viewController = SegmentationViewController(segmentationImage: segmentationImage)
        viewController.frameRect = frameRect
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: SegmentationViewController, context: Context) {
        uiViewController.segmentationView.image = segmentationImage
    }
}

