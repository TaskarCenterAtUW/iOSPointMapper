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
        static let inputSize: CGSize = CGSize(width: 518, height: 392)
    }
    
    struct WorkspaceConstants {
        static let primaryWorkspaceIds: [String] = ["288", "349"]
//      "252", "322", "368", "374", "378", "381", "384", "323", "369", "156", "375", "379"]
    }
}
