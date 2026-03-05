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

@MainActor
protocol TestCameraProcessingOutputConsumer: AnyObject {
    func cameraImage(_ delegate: TestCameraProcessingDelegate,
                        metalContext: MetalContext,
                        cameraImage: CIImage,
                        for frame: ARFrame?)
    func cameraOutputImage(_ delegate: TestCameraProcessingDelegate,
                           metalContext: MetalContext,
                           segmentationImage: CIImage?,
                           segmentationBoundingFrameImage: CIImage?,
                           for frame: ARFrame?
    )
    func cameraOutputMesh(_ delegate: TestCameraProcessingDelegate,
                           metalContext: MetalContext,
                           meshGPUSnapshot: MeshGPUSnapshot,
                           for meshAnchors: [ARMeshAnchor]?,
                           cameraTransform: simd_float4x4,
                           cameraIntrinsics: simd_float3x3,
                           segmentationLabelImage: CIImage,
                           accessibilityFeatureClasses: [AccessibilityFeatureClass]
    )
    func getMeshRecordDetails() -> (
        records: [AccessibilityFeatureClass: SegmentationMeshRecord],
        otherDetails: MeshOtherDetails?
    )
    func resumeSession()
    func pauseSession()
}

/**
    A  specialview controller that manages the AR camera view and segmentation display.
    Requires an ARSessionCameraProcessingDelegate to process camera frames (not just any ARSessionDelegate).
 
    - NOTE:
    Also processes the mesh data and (optionally) maintains the mesh entities in the ARView scene.
 */
@MainActor
final class TestCameraViewController: UIViewController, TestCameraProcessingOutputConsumer {
    var arSessionCameraProcessingDelegate: TestCameraProcessingDelegate
    
    /**
     Sub-view containing the other views
     */
    private let subView = UIView()
    private var aspectConstraint: NSLayoutConstraint!
    private var aspectRatio: CGFloat = 3/4
    private var fitWidthConstraint: NSLayoutConstraint!
    private var fitHeightConstraint: NSLayoutConstraint!
    private var topAlignConstraint: [NSLayoutConstraint] = []
    private var leadingAlignConstraint: [NSLayoutConstraint] = []
    private var videoFormatImageResolution: CGSize? = nil
    
    private let imageView: UIImageView = {
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
    
    init(arSessionCameraProcessingDelegate: TestCameraProcessingDelegate) {
        self.arSessionCameraProcessingDelegate = arSessionCameraProcessingDelegate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        
        view.addSubview(subView)
        subView.clipsToBounds = true
        
        subView.translatesAutoresizingMaskIntoConstraints = false
        aspectConstraint = subView.widthAnchor.constraint(
            equalTo: subView.heightAnchor,
            multiplier: aspectRatio
        )
        aspectConstraint.priority = .required
        
        NSLayoutConstraint.deactivate(subView.constraints)
        let subViewBoundsConstraints: [NSLayoutConstraint] = [
            subView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor),
            subView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor),
            subView.topAnchor.constraint(greaterThanOrEqualTo: view.topAnchor),
            subView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            aspectConstraint
        ]
        NSLayoutConstraint.activate(subViewBoundsConstraints)
        
        fitWidthConstraint = subView.widthAnchor.constraint(equalTo: view.widthAnchor)
        fitHeightConstraint = subView.heightAnchor.constraint(equalTo: view.heightAnchor)
        topAlignConstraint = [
            subView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            subView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ]
        leadingAlignConstraint = [
            subView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            subView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ]
        
        subView.addSubview(imageView)
        subView.addSubview(segmentationBoundingFrameView)
        subView.addSubview(segmentationImageView)
        
        constraintChildViewToParent(childView: imageView, parentView: subView)
        constraintChildViewToParent(childView: segmentationBoundingFrameView, parentView: subView)
        constraintChildViewToParent(childView: segmentationImageView, parentView: subView)

        arSessionCameraProcessingDelegate.outputConsumer = self
        
        updateFitConstraints()
        updateAlignConstraints()
        updateAspectRatio()
        arSessionCameraProcessingDelegate.setOrientation(getOrientation())
    }
    
    private func constraintChildViewToParent(childView: UIView, parentView: UIView) {
        NSLayoutConstraint.deactivate(childView.constraints)
        NSLayoutConstraint.activate([
            childView.topAnchor.constraint(equalTo: parentView.topAnchor),
            childView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            childView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            childView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
        ])
    }
    
    private func updateAspectRatio() {
        if let videoFormatImageResolution = videoFormatImageResolution {
            aspectRatio = videoFormatImageResolution.width / videoFormatImageResolution.height
        }
        if isPortrait() {
            // The ARView aspect ratio for portrait is height / width
            aspectRatio = 1 / aspectRatio
        }
        
        aspectConstraint.isActive = false
        aspectConstraint = subView.widthAnchor.constraint(
            equalTo: subView.heightAnchor,
            multiplier: aspectRatio
        )
        aspectConstraint.isActive = true
        view.setNeedsLayout()
    }
    
    private func updateFitConstraints() {
        if isPortrait() {
            fitHeightConstraint.isActive = false
            fitWidthConstraint.isActive = true
        } else {
            fitWidthConstraint.isActive = false
            fitHeightConstraint.isActive = true
        }
    }
    
    private func updateAlignConstraints() {
        // If portrait, align top; else align leading
        if isPortrait() {
            NSLayoutConstraint.deactivate(leadingAlignConstraint)
            NSLayoutConstraint.activate(topAlignConstraint)
        } else {
            NSLayoutConstraint.deactivate(topAlignConstraint)
            NSLayoutConstraint.activate(leadingAlignConstraint)
        }
    }
    
    func getOrientation() -> UIInterfaceOrientation {
        // TODO: While we are requested to replace usage with effectiveGeometry.interfaceOrientation,
        //  it seems to cause issues with getting the correct orientation.
        //  Need to investigate further.
        if let io = view.window?.windowScene?.interfaceOrientation {
            return io
        }
        // Fallback for early lifecycle / no window
        if view.bounds.height >= view.bounds.width {
            return .portrait
        }
        return .landscapeLeft
    }
    
    private func isPortrait() -> Bool {
        return getOrientation().isPortrait
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFitConstraints()
        updateAlignConstraints()
        updateAspectRatio()
        arSessionCameraProcessingDelegate.setOrientation(getOrientation())
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateFitConstraints()
            self.updateAlignConstraints()
            self.updateAspectRatio()
            self.arSessionCameraProcessingDelegate.setOrientation(self.getOrientation())
            self.view.layoutIfNeeded()
        })
    }

//    deinit {
//        pauseSession()
//    }
    
    /**
    Resumes the AR session and sets its delegate.
     */
    func resumeSession() {
        /// Nothing for now
    }
    
    /**
    Pauses the AR session and removes its delegate.
     */
    func pauseSession() {
        /// Nothing for now
    }
    
    func cameraImage(_ delegate: TestCameraProcessingDelegate,
                     metalContext: MetalContext,
                     cameraImage: CIImage,
                     for frame: ARFrame?) {
        let newImageResolution = CGSize(width: cameraImage.extent.width, height: cameraImage.extent.height)
        if videoFormatImageResolution == nil || videoFormatImageResolution != newImageResolution {
            videoFormatImageResolution = newImageResolution
            updateAspectRatio()
        }
        if let cameraCGImage = metalContext.ciContext.createCGImage(cameraImage, from: cameraImage.extent) {
            self.imageView.image = UIImage(cgImage: cameraCGImage)
        } else {
            self.imageView.image = nil
        }
    }
        
    
    func cameraOutputImage(_ delegate: TestCameraProcessingDelegate,
                           metalContext: MetalContext,
                           segmentationImage: CIImage?, segmentationBoundingFrameImage: CIImage?,
                           for frame: ARFrame?) {
        if let segmentationImage = segmentationImage,
           let segmentationCGImage = metalContext.ciContext.createCGImage(segmentationImage, from: segmentationImage.extent) {
            self.segmentationImageView.image = UIImage(cgImage: segmentationCGImage)
        } else {
            self.segmentationImageView.image = nil
        }
        if let boundingFrameImage = segmentationBoundingFrameImage {
            self.segmentationBoundingFrameView.image = UIImage(ciImage: boundingFrameImage)
        }
    }
    
    func cameraOutputMesh(_ delegate: TestCameraProcessingDelegate,
                           metalContext: MetalContext,
                           meshGPUSnapshot: MeshGPUSnapshot,
                           for meshAnchors: [ARMeshAnchor]?,
                           cameraTransform: simd_float4x4,
                           cameraIntrinsics: simd_float3x3,
                           segmentationLabelImage: CIImage,
                           accessibilityFeatureClasses: [AccessibilityFeatureClass]
    ) {
        /// Nothing for now
    }
    
    func getMeshRecordDetails() -> (
        records: [AccessibilityFeatureClass: SegmentationMeshRecord],
        otherDetails: MeshOtherDetails?
    ) {
        return ([:], nil)
    }
}

struct HostedTestCameraViewContainer: UIViewControllerRepresentable {
    var arSessionCameraProcessingDelegate: TestCameraProcessingDelegate
    
    func makeUIViewController(context: Context) -> TestCameraViewController {
        let vc = TestCameraViewController(arSessionCameraProcessingDelegate: arSessionCameraProcessingDelegate)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: TestCameraViewController, context: Context) {
    }
    
    static func dismantleUIViewController(_ uiViewController: TestCameraViewController, coordinator: ()) {
    }
}
