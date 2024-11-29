//
//  IOSAccessAssessmentApp.swift
//  IOSAccessAssessment
//
//  Created by Sai on 1/24/24.
//

import SwiftUI

@main
struct IOSAccessAssessmentApp: App {
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false
    private let tokenRefreshService = TokenRefreshService()

    init() {
        isAuthenticated = KeychainService().isTokenValid()
        if isAuthenticated {
            tokenRefreshService.startTokenRefresh()
        }
    }

    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                SetupView(onLogout: handleLogout)
            } else {
                LoginView(onLoginSuccess: handleLoginSuccess)
            }
        }
    }

    private func handleLoginSuccess() {
        isAuthenticated = true
        tokenRefreshService.startTokenRefresh()
    }

    private func handleLogout() {
        isAuthenticated = false
        tokenRefreshService.stopTokenRefresh()
        AuthService().logout()
    }
}
