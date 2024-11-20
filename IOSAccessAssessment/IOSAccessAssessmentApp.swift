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
        let isTokenValid = keychainService.isTokenValid()
        _isAuthenticated = State(initialValue: isTokenValid)
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
