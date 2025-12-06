//
//  APIEnvironment.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 10/1/25.
//

import Foundation

/**
 TODO: Use this to replace the environment-agnostic APIConstants
 */
enum APIEnvironment: String, CaseIterable {
//    case development = "Development"
    case staging = "Staging"
//    case production = "Production"
    
    static var `default`: APIEnvironment {
        return .staging
    }
    
    var workspaceBaseURL: String {
        switch self {
//        case .development:
//            return "https://api.workspaces-dev.sidewalks.washington.edu/api/v1"
        case .staging:
            return "https://api.workspaces-stage.sidewalks.washington.edu/api/v1"
//        case .production:
//            return "https://api.workspaces.sidewalks.washington.edu/api/v1"
        }
    }
    
    var loginBaseURL: String {
        switch self {
//        case .development:
//            return "https://tdei-api-dev.azurewebsites.net/api/v1"
        case .staging:
            return "https://tdei-gateway-stage.azurewebsites.net/api/v1"
//        case .production:
//            return "https://tdei-gateway-prod.azurewebsites.net/api/v1"
        }
    }
    
    var osmBaseURL: String {
           switch self {
//           case .development:
//               return "https://osm-workspaces-proxy.azurewebsites.net/dev/api/0.6"
           case .staging:
               return "https://osm-workspaces-proxy.azurewebsites.net/stage/api/0.6"
//           case .production:
//               return "https://osm-workspaces-proxy.azurewebsites.net/prod/api/0.6"
           }
       }
    
    var userProfileBaseURL: String {
        switch self {
//        case .development:
//            return "https://tdei-usermanagement-be-dev.azurewebsites.net/api/v1"
        case .staging:
            return "https://tdei-usermanagement-stage.azurewebsites.net/api/v1"
//        case .production:
//            return "https://tdei-usermanagement-prod.azurewebsites.net/api/v1"
        }
    }
    
    var displayString: String {
        switch self {
//        case .development:
//            return "Development"
        case .staging:
            return "Staging"
//        case .production:
//            return "Production"
        }
    }
}
