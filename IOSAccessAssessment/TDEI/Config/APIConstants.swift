//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/18/25.
//

struct APIConstants {    
    enum AttributeKeys {
        static let id = "id"
        static let oldId = "old_id"
        static let newId = "new_id"
        static let version = "version"
        static let newVersion = "new_version"
    }
    
    enum TagKeys {
        static let appTagPrefix = "ios.pointmapper"
        static let calculatedTagPrefix = "\(appTagPrefix):calculated"
        static let captureTagPrefix = "\(appTagPrefix):capture"
        /// Tags used to track capture-specific information
        static let sessionIdKey = "\(appTagPrefix):sessionId"
        static let captureIdKey = "\(captureTagPrefix):id"
        
        /// Tags for original location tracking
        static let calculatedLatitudeKey = "\(calculatedTagPrefix):latitude"
        static let calculatedLongitudeKey = "\(calculatedTagPrefix):longitude"
        
        /// Other tags used for post-hoc analysis
        static let captureLatitudeKey = "\(captureTagPrefix):latitude"
        static let captureLongitudeKey = "\(captureTagPrefix):longitude"
        static let lidarDepthKey = "\(appTagPrefix):lidarDepth"
        static let latitudeDeltaKey = "\(appTagPrefix):latitudeDelta"
        static let longitudeDeltaKey = "\(appTagPrefix):longitudeDelta"
        static let enhancedAnalysisModeKey = "\(appTagPrefix):enhancedAnalysisMode"
    }
    
    enum OtherConstants {
        static let classLabelPlaceholder = "Unknown"
    }
}
