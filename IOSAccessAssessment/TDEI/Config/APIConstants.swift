//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/18/25.
//

struct APIConstants {
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
        /// Tags used to track capture-specific information
        static let sessionIdKey = "\(appTagPrefix):sessionId"
        static let captureIdKey = "\(appTagPrefix):captureId"
        
        /// Tags used for post-hoc analysis
        static let captureLatitudeKey = "\(appTagPrefix):captureLatitude"
        static let captureLongitudeKey = "\(appTagPrefix):captureLongitude"
        static let lidarDepthKey = "\(appTagPrefix):lidarDepth"
        static let latitudeDeltaKey = "\(appTagPrefix):latitudeDelta"
        static let longitudeDeltaKey = "\(appTagPrefix):longitudeDelta"
    }
    
    enum OtherConstants {
        static let classLabelPlaceholder = "Unknown"
    }
}
