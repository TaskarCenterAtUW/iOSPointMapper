//
//  TestCameraManager.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/5/26.
//

import ARKit
import RealityKit
import Combine
import simd

final class TestCameraManager: NSObject, ObservableObject, ARSessionCameraProcessingDelegate {
    var selectedClasses: [AccessibilityFeatureClass] = []
    var segmentationPipeline: SegmentationARPipeline? = nil
    
    // Consumer that will receive processed overlays (weak to avoid retain cycles)
    weak var outputConsumer: ARSessionCameraProcessingOutputConsumer? = nil
    
    @Published var isConfigured: Bool = false
    
    // Latest processed results
    var cameraImageResults: ARCameraImageResults?
    var cameraMeshResults: ARCameraMeshResults?
    var cameraCache: ARCameraCache = ARCameraCache()
    
    func setVideoFormatImageResolution(_ imageResolution: CGSize) {
        /// Do nothing for now
    }
    
    func setOrientation(_ orientation: UIInterfaceOrientation) {
        /// Do nothing for now
    }
    
    
}
