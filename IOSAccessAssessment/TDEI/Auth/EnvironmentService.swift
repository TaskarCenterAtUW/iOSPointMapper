//
//  EnvironmentService.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/26/26.
//

import Foundation

class EnvironmentService {
    static let shared = EnvironmentService()
    
    var environment: APIEnvironment {
        get {
            if let savedValue = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.selectedEnvironmentKey),
               let savedEnvironment = APIEnvironment(rawValue: savedValue) {
                return savedEnvironment
            }
            return .staging // default value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Constants.UserDefaultsKeys.selectedEnvironmentKey)
        }
    }
}
