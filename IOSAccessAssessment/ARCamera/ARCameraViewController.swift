//
//  ARCameraViewController.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 10/24/25.
//

import SwiftUI
import RealityKit
import ARKit
import CoreImage
import CoreImage.CIFilterBuiltins
import simd

final class ARCameraViewController: UIViewController {
    private let arView: ARView = {
        let v = ARView(frame: .zero)
        v.automaticallyConfigureSession = false
        return v
    }()
    private var aspectConstraint: NSLayoutConstraint!
    
    private let overlayImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor(white: 0, alpha: 0.0)
        iv.isUserInteractionEnabled = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private let segmentationFrameImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor(white: 0, alpha: 0.0)
        iv.isUserInteractionEnabled = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    
}

struct HostedARCameraViewContainer: UIViewControllerRepresentable {
    
    func makeUIViewController(context: Context) -> ARCameraViewController {
        let vc = ARCameraViewController()
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ARCameraViewController, context: Context) {
    }
    
    static func dismantleUIViewController(_ uiViewController: ARCameraViewController, coordinator: ()) {
    }
}
