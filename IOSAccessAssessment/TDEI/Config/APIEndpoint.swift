//
//  APIEndpoint.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/26/26.
//

import Foundation
import CoreLocation

/**
    Struct to define API endpoints for the application. This can be expanded to include various endpoints for fetching and updating accessibility features, user data, etc.
 
    - NOTE:
    For now, only returns the URL.
    In the future, this can be expanded to include the headers, body, and other parameters needed for making API requests.
 */
struct APIEndpoint {
    static let login = { (environment: APIEnvironment) in
        let baseURL = URL(string: environment.loginBaseURL)
        return baseURL?.appending(path: "authenticate")
    }
    
    static let refreshToken = { (environment: APIEnvironment) in
        let baseURL = URL(string: environment.loginBaseURL)
        return baseURL?.appending(path: "refresh-token")
    }
    
    static let getWorkspaces = { (environment: APIEnvironment) in
        let baseURL = URL(string: environment.workspaceBaseURL)
        return baseURL?.appending(path: "workspaces/mine")
    }
    
    static let getMapData = { (environment: APIEnvironment) in
        let baseURL = URL(string: environment.osmBaseURL)
        return baseURL?.appending(path: "map.json")
    }
    
    static let createChangeset = { (environment: APIEnvironment) in
        let baseURL = URL(string: environment.osmBaseURL)
        return baseURL?.appending(path: "changeset/create")
    }
    
    static let uploadChanges = { (environment: APIEnvironment, changesetId: String) in
        let baseURL = URL(string: environment.osmBaseURL)
        return baseURL?.appending(path: "changeset/\(changesetId)/upload")
    }
    
    static let closeChangeset = { (environment: APIEnvironment, changesetId: String) in
        let baseURL = URL(string: environment.osmBaseURL)
        return baseURL?.appending(path: "changeset/\(changesetId)/close")
    }
}
