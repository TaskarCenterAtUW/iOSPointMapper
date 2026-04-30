//
//  PointNMapConstants.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/26.
//
import SwiftUI

public struct PointNMapConstants {
    // Supported Classes
    static let SelectedAccessibilityFeatureConfig: AccessibilityFeatureClassConfig = AccessibilityFeatureConfig.mapillaryCustom11Config
    
    public struct DepthConstants {
        /// Model-specific SharedAppConstants
        public static let inputSize: CGSize = CGSize(width: 518, height: 392)
        
        /// General SharedAppConstants
        public static let depthMinThreshold: Float = 0.0
        public static let depthMaxThreshold: Float = 5.0
    }
    
    public struct DamageDetectionConstants {
        /// Model-specific SharedAppConstants
        public static let damageDetectionModelURL: URL? = PointNMapSharedResources.bundle.url(
            forResource: "v8n_175_16_960", withExtension: "mlmodelc"
        )
        public static let inputSize: CGSize = CGSize(width: 640, height: 640)
    }
    
    public struct SurfaceIntegrityConstants {
        /// Image (world point) based SharedAppConstants
        public static let imagePlaneAngularDeviationThreshold: Float = 15.0 // Unit: degrees
        public static let imageDeviantPointProportionThreshold: Float = 0.1 // Unit: percentage (0 to 1)
        public static let imageBoundingBoxAreaThreshold: Float = 0.1 // Unit: m2
        public static let imageBoundingBoxAngularStdThreshold: Float = 10.0 // Unit: degrees
        
        /// Mesh based SharedAppConstants
        public static let meshPlaneAngularDeviationThreshold: Float = 7.5 // Unit: degrees
        public static let meshDeviantPolygonProportionThreshold: Float = 0.1 // Unit: percentage (0 to 1)
        public static let meshBoundingBoxAreaThreshold: Float = 0.1 // Unit: m2
        public static let meshBoundingBoxAngularStdThreshold: Float = 5.0 // Unit: degrees
    }
    
    public struct WorkspaceConstants {
        public static let primaryWorkspaceIds: [String] = ["1830"]
//        ["1463"]
//        ["288", "349", "1411"]
//      "252", "322", "368", "374", "378", "381", "384", "323", "369", "156", "375", "379"]
        
        public static let fetchRadiusInMeters: Double = 100.0
        public static let fetchUpdateRadiusThresholdInMeters: Double = 50.0
        public static let updateElementDistanceThresholdInMeters: Double = 20.0
    }
    
    public struct OtherConstants {
        public static let directionAlignmentDotProductThreshold: Float = 0.866 // cos(30 degrees)
    }
    
    public struct UserDefaultsKeys {
        /// Environment selection
        public static let selectedEnvironmentKey = "selectedEnvironment"
        
        /// Workspace selection
        public static let selectedWorkspaceIdKey = "selectedWorkspaceId"
        public static let selectedWorkspaceTitleKey = "selectedWorkspaceTitle"
        
        /// User settings
        public static let isEnhancedAnalysisEnabledKey = "isEnhancedAnalysisEnabled"
        public static let appModeKey = "appMode"
    }
}
