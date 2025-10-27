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

/// The consumer of post-processed camera outputs (e.g., overlay images).
@MainActor
protocol ARSessionCameraProcessingOutputConsumer: AnyObject {
    func cameraManager(_ manager: ARSessionCameraProcessingDelegate,
                       cameraAspectMultipler: CGFloat,
                       segmentationImage: CIImage,
                       segmentationBoundingFrameImage: CIImage?,
                       for frame: ARFrame)
}

protocol ARSessionCameraProcessingDelegate: ARSessionDelegate, AnyObject {
    /// Set by the host (e.g., ARCameraViewController) to receive processed overlays.
    @MainActor
    var outputConsumer: ARSessionCameraProcessingOutputConsumer? { get set }
}

/**
    A  specialview controller that manages the AR camera view and segmentation display.
    Requires an ARSessionCameraProcessingDelegate to process camera frames (not just any ARSessionDelegate).
 */
@MainActor
final class ARCameraViewController: UIViewController, ARSessionCameraProcessingOutputConsumer {
    var arCameraManager: ARCameraManager
    
    private let arView: ARView = {
        let v = ARView(frame: .zero)
        v.automaticallyConfigureSession = false
        return v
    }()
    private var aspectConstraint: NSLayoutConstraint!
    // MARK: Hard-coded aspect ratio constraint of 4:3. Need to make it dependent on camera feed.
    private var aspectMultiplier: CGFloat = 1.0
    
    /**
     A static frame view to show the bounds of segmentation
     */
    private let segmentationBoundingFrameView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor(white: 0, alpha: 0.0)
        iv.isUserInteractionEnabled = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    /**
     An image view to display segmentation mask
     */
    private let segmentationImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12
        iv.backgroundColor = UIColor(white: 0, alpha: 0.0)
        iv.isUserInteractionEnabled = false
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let processQueue = DispatchQueue(label: "ar.host.process.queue")
    
    init(arCameraManager: ARCameraManager) {
        self.arCameraManager = arCameraManager
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(arView)
        arView.translatesAutoresizingMaskIntoConstraints = false
        
        arView.addSubview(segmentationBoundingFrameView)
        arView.addSubview(segmentationImageView)
        applyDebugIfNeeded()
        
        updateLayoutViews(aspectMultiplier: aspectMultiplier)

        arView.session.delegate = arCameraManager
        arCameraManager.outputConsumer = self
    }
    
    private func updateLayoutViews(aspectMultiplier: CGFloat) {
        NSLayoutConstraint.deactivate(arView.constraints)
        NSLayoutConstraint.deactivate(segmentationImageView.constraints)
        NSLayoutConstraint.deactivate(segmentationBoundingFrameView.constraints)
        
        view.clipsToBounds = true
        aspectConstraint = view.widthAnchor.constraint(equalTo: view.heightAnchor, multiplier: aspectMultiplier)
        aspectConstraint.priority = .required
        aspectConstraint.isActive = true
        
        applyLayoutConstraints(subview: arView)
        applyLayoutConstraints(subview: segmentationBoundingFrameView)
        applyLayoutConstraints(subview: segmentationImageView)
    }
    
    private func applyLayoutConstraints(subview: UIView) {
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: view.topAnchor),
            subview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//            view.centerXAnchor.constraint(equalTo: view.centerXAnchor)
            subview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func applyDebugIfNeeded() {
        arView.environment.sceneUnderstanding.options.insert(.occlusion)
        arView.debugOptions.insert(.showSceneUnderstanding)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        runSessionIfNeeded()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
//        print("container:", view.bounds, "arView:", arView.frame)
    }

//    deinit {
//        pauseSession()
//    }
    
    func runSessionIfNeeded() {
        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        arView.session.run(config, options: [])
    }
    
    /**
    Pauses the AR session and removes its delegate.
     NOTE: Only call this method when you are sure you want to stop the AR session permanently. We have to figure out a way to pause and resume sessions properly.
     */
    func pauseSession() {
        arView.session.delegate = nil
        arView.session.pause()
    }
    
    func cameraManager(_ manager: any ARSessionCameraProcessingDelegate,
                       cameraAspectMultipler: CGFloat,
                       segmentationImage: CIImage, segmentationBoundingFrameImage: CIImage?,
                       for frame: ARFrame) {
        if abs(cameraAspectMultipler - aspectMultiplier) > 0.01 {
            aspectMultiplier = cameraAspectMultipler
            updateLayoutViews(aspectMultiplier: aspectMultiplier)
        }
        self.segmentationImageView.image = UIImage(ciImage: segmentationImage)
        if let boundingFrameImage = segmentationBoundingFrameImage {
            self.segmentationBoundingFrameView.image = UIImage(ciImage: boundingFrameImage)
        } else {
            self.segmentationBoundingFrameView.image = nil
        }
    }
}

struct HostedARCameraViewContainer: UIViewControllerRepresentable {
    @ObservedObject var arCameraManager: ARCameraManager
    
    func makeUIViewController(context: Context) -> ARCameraViewController {
        let vc = ARCameraViewController(arCameraManager: arCameraManager)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ARCameraViewController, context: Context) {
    }
    
    static func dismantleUIViewController(_ uiViewController: ARCameraViewController, coordinator: ()) {
    }
}
