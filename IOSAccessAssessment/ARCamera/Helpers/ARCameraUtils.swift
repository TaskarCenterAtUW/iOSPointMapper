//
//  ARCameraUtils.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/22/25.
//

import ARKit

class ARCameraUtils {
    static func checkLidarAvailability() -> Bool {
        // Check if LiDAR is available on the device
        return ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) ||
        ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
    }
}
