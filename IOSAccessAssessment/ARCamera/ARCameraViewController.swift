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
    func cameraManagerImage(_ manager: ARSessionCameraProcessingDelegate,
                            segmentationImage: CIImage?,
                            segmentationBoundingFrameImage: CIImage?,
                            for frame: ARFrame
    )
    func cameraManagerMesh(_ manager: ARSessionCameraProcessingDelegate,
                           meshGPUContext: MeshGPUContext,
                           meshSnapshot: MeshSnapshot,
                           for anchors: [ARAnchor],
                           cameraTransform: simd_float4x4,
                           cameraIntrinsics: simd_float3x3,
                           segmentationLabelImage: CIImage,
    )
}

protocol ARSessionCameraProcessingDelegate: ARSessionDelegate, AnyObject {
    /// Set by the host (e.g., ARCameraViewController) to receive processed overlays.
    @MainActor
    var outputConsumer: ARSessionCameraProcessingOutputConsumer? { get set }
    /// This method will help set up any configuration that depends on the video format image resolution.
    @MainActor
    func setVideoFormatImageResolution(_ imageResolution: CGSize)
    @MainActor
    func setOrientation(_ orientation: UIInterfaceOrientation)
}

/**
    A  specialview controller that manages the AR camera view and segmentation display.
    Requires an ARSessionCameraProcessingDelegate to process camera frames (not just any ARSessionDelegate).
 */
@MainActor
final class ARCameraViewController: UIViewController, ARSessionCameraProcessingOutputConsumer {
    var arCameraManager: ARCameraManager
    
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
    
    private let arView: ARView = {
        let v = ARView(frame: .zero)
        v.automaticallyConfigureSession = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private var videoFormatImageResolution: CGSize? = nil
    
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
    
    // Mesh-related properties
    private var anchorEntity: AnchorEntity = AnchorEntity(world: .zero)
    private var meshEntities: [Int: SegmentedMeshRecord] = [:]
    
    init(arCameraManager: ARCameraManager) {
        self.arCameraManager = arCameraManager
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
        
        subView.addSubview(arView)
        subView.addSubview(segmentationBoundingFrameView)
        subView.addSubview(segmentationImageView)
        
        constraintChildViewToParent(childView: arView, parentView: subView)
        constraintChildViewToParent(childView: segmentationBoundingFrameView, parentView: subView)
        constraintChildViewToParent(childView: segmentationImageView, parentView: subView)

        arView.session.delegate = arCameraManager
        arCameraManager.outputConsumer = self
        
        applyDebugIfNeeded()
        updateFitConstraints()
        updateAlignConstraints()
        updateAspectRatio()
        arCameraManager.setOrientation(getOrientation())
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
        updateFitConstraints()
        updateAlignConstraints()
        updateAspectRatio()
        arCameraManager.setOrientation(getOrientation())
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateFitConstraints()
            self.updateAlignConstraints()
            self.updateAspectRatio()
            self.arCameraManager.setOrientation(self.getOrientation())
            self.view.layoutIfNeeded()
        })
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
        // Update aspectRatio based on video format
        let videoFormat = config.videoFormat
        videoFormatImageResolution = videoFormat.imageResolution
        // Run the session
        arView.session.run(config, options: [])
        // Add Anchor Entity
        arView.scene.addAnchor(anchorEntity)
        // Set the image resolution in the camera manager
        arCameraManager.setVideoFormatImageResolution(videoFormat.imageResolution)
    }
    
    /**
    Pauses the AR session and removes its delegate.
     NOTE: Only call this method when you are sure you want to stop the AR session permanently. We have to figure out a way to pause and resume sessions properly.
     */
    func pauseSession() {
        arView.session.delegate = nil
        arView.session.pause()
    }
    
    func cameraManagerImage(_ manager: any ARSessionCameraProcessingDelegate,
                       segmentationImage: CIImage?, segmentationBoundingFrameImage: CIImage?,
                       for frame: ARFrame) {
        if let segmentationImage = segmentationImage {
            self.segmentationImageView.image = UIImage(ciImage: segmentationImage)
        } else {
            self.segmentationImageView.image = nil
        }
        if let boundingFrameImage = segmentationBoundingFrameImage {
            self.segmentationBoundingFrameView.image = UIImage(ciImage: boundingFrameImage)
        }
    }
    
    func cameraManagerMesh(_ manager: any ARSessionCameraProcessingDelegate,
                           meshGPUContext: MeshGPUContext,
                           meshSnapshot: MeshSnapshot,
                           for anchors: [ARAnchor],
                           cameraTransform: simd_float4x4,
                           cameraIntrinsics: simd_float3x3,
                           segmentationLabelImage: CIImage,
    ) {
        // MARK: Hard-coding values temporarily; need to map anchors properly later
        let anchorIndex = 0
        let color = UIColor.blue
        let name = "PostProcessedMesh"
        if let existingMeshRecord = meshEntities[anchorIndex] {
            // Update existing mesh entity
            do {
                try existingMeshRecord.replace(
                    meshSnapshot: meshSnapshot,
                    segmentationImage: segmentationLabelImage,
                    cameraTransform: cameraTransform,
                    cameraIntrinsics: cameraIntrinsics
                )
            } catch {
                print("Error updating mesh entity: \(error)")
            }
        } else {
            // Create new mesh entity
            do {
                let meshRecord = try SegmentedMeshRecord(
                    meshGPUContext,
                    meshSnapshot: meshSnapshot,
                    segmentationImage: segmentationLabelImage,
                    cameraTransform: cameraTransform,
                    cameraIntrinsics: cameraIntrinsics,
                    segmentationClass: Constants.SelectedSegmentationConfig.classes.first!,
                    color: color, opacity: 0.7, name: name
                )
                meshEntities[anchorIndex] = meshRecord
                anchorEntity.addChild(meshRecord.entity)
            } catch {
                print("Error creating mesh entity: \(error)")
            }
        }
    }
    
    private func createMeshEntity(
        triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)],
        color: UIColor = .green,
        opacity: Float = 0.4,
        name: String = "Mesh"
    ) -> ModelEntity? {
        if (triangles.isEmpty) {
            return nil
        }
        
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for (i, triangle) in triangles.enumerated() {
            let baseIndex = UInt32(i * 3)
            positions.append(triangle.0)
            positions.append(triangle.1)
            positions.append(triangle.2)
            indices.append(contentsOf: [baseIndex, baseIndex + 1, baseIndex + 2])
        }

        var meshDescriptors = MeshDescriptor(name: name)
        meshDescriptors.positions = MeshBuffers.Positions(positions)
        meshDescriptors.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [meshDescriptors]) else {
            return nil
        }

        let material = UnlitMaterial(color: color.withAlphaComponent(CGFloat(opacity)))
        let entity = ModelEntity(mesh: mesh, materials: [material])
        return entity
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
