//
//  ARCameraUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/22/25.
//

import ARKit

class ARCameraUtils {
    static func checkDepthSupport() -> Bool {
        // Check if LiDAR is available on the device
        print("Checking if ARKit supports scene depth...")
        print("ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth): \(ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth))")
        print("ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth): \(ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth))")
        return ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) ||
        ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
    }
}
