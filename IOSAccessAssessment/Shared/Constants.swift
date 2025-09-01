//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/24/24.
//

import SwiftUI

// Constants related to the supported classes
struct Constants {
    // Supported Classes
    static let SelectedSegmentationConfig: SegmentationClassConfig = SegmentationConfig.cocoCustom11Config
    
    struct DepthConstants {
        static let inputSize: CGSize = CGSize(width: 518, height: 392)
    }
    
    struct WorkspaceConstants {
        static let primaryWorkspaceIds: [String] = ["288"]
    }
}
