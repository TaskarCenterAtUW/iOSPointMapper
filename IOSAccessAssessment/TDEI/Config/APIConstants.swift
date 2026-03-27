//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/18/25.
//

struct APIConstants {
    /// TODO: Replace APIConstants.Constants with configurations stored in APIEnvironment. 
    enum Constants {
        // For the URLs, we only use staging for now
        static let baseUrl = "https://osm.workspaces-stage.sidewalks.washington.edu/api/0.6"
        static let tdeiCoreBaseUrl = "https://tdei-gateway-stage.azurewebsites.net"
        static let tdeiCoreAuthUrl = "https://tdei-gateway-stage.azurewebsites.net/api/v1/authenticate"
        static let tdeiCoreRefreshAuthUrl = "https://tdei-gateway-stage.azurewebsites.net/api/v1/refresh-token"
        static let workspacesAPIBaseUrl = "https://api.workspaces-stage.sidewalks.washington.edu/api/v1"
        static let workspacesOSMBaseUrl = "https://osm.workspaces-stage.sidewalks.washington.edu/api/0.6"
    }
    
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
