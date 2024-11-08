//
//  IOSAccessAssessmentApp.swift
//  IOSAccessAssessment
//
//  Created by Sai on 1/24/24.
//

import SwiftUI

@main
struct IOSAccessAssessmentApp: App {
    private let keychainService = KeychainService()
    @State private var isAuthenticated: Bool
    
    init() {
        let tokenExists = keychainService.getValue(for: "token") != nil
        _isAuthenticated = State(initialValue: tokenExists)
    }
    
    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                SetupView()
            } else {
                LoginView(isAuthenticated: $isAuthenticated)
            }
        }
    }
}
