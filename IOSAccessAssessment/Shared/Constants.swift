//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/24/24.
//

import SwiftUI

/**
 Global Constants used across the app.
 */
struct Constants {
    // Supported Classes
    static let SelectedAccessibilityFeatureConfig: AccessibilityFeatureClassConfig = AccessibilityFeatureConfig.mapillaryCustom11Config
    
    struct DepthConstants {
        /// Model-specific constants
        static let inputSize: CGSize = CGSize(width: 518, height: 392)
        
        /// General constants
        static let depthMinThreshold: Float = 0.0
        static let depthMaxThreshold: Float = 5.0
    }
    
    struct DamageDetectionConstants {
        /// Model-specific constants
        static let damageDetectionModelURL: URL? = Bundle.main.url(forResource: "v8n_175_16_960", withExtension: "mlmodelc")
        static let inputSize: CGSize = CGSize(width: 640, height: 640)
    }
    
    struct SurfaceIntegrityConstants {
        /// Image (world point) based constants
        static let imagePlaneAngularDeviationThreshold: Float = 15.0 // Unit: degrees
        static let imageDeviantPointProportionThreshold: Float = 0.1 // Unit: percentage (0 to 1)
        static let imageBoundingBoxAreaThreshold: Float = 0.1 // Unit: m2
        static let imageBoundingBoxAngularStdThreshold: Float = 10.0 // Unit: degrees
        
        /// Mesh based constants
        static let meshPlaneAngularDeviationThreshold: Float = 7.5 // Unit: degrees
        static let meshDeviantPolygonProportionThreshold: Float = 0.1 // Unit: percentage (0 to 1)
        static let meshBoundingBoxAreaThreshold: Float = 0.1 // Unit: m2
        static let meshBoundingBoxAngularStdThreshold: Float = 5.0 // Unit: degrees
    }
    
    struct WorkspaceConstants {
        static let primaryWorkspaceIds: [String] = ["1731"]
//        ["1463"]
//        ["288", "349", "1411"]
//      "252", "322", "368", "374", "378", "381", "384", "323", "369", "156", "375", "379"]
        
        static let fetchRadiusInMeters: Double = 100.0
        static let fetchUpdateRadiusThresholdInMeters: Double = 50.0
        static let updateElementDistanceThresholdInMeters: Double = 20.0
    }
    
    struct OtherConstants {
        static let directionAlignmentDotProductThreshold: Float = 0.866 // cos(30 degrees)
    }
    
    struct UserDefaultsKeys {
        /// Environment selection
        static let selectedEnvironmentKey = "selectedEnvironment"
        
        /// Workspace selection
        static let selectedWorkspaceIdKey = "selectedWorkspaceId"
        static let selectedWorkspaceTitleKey = "selectedWorkspaceTitle"
        
        /// User settings
        static let isEnhancedAnalysisEnabledKey = "isEnhancedAnalysisEnabled"
        static let appModeKey = "appMode"
    }
}
