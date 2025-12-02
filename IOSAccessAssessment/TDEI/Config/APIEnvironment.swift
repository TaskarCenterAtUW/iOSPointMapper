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
}
