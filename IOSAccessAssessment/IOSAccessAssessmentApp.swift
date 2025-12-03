//
//  IOSAccessAssessmentApp.swift
//  IOSAccessAssessment
//
//  Created by Sai on 1/24/24.
//

import SwiftUI
import TipKit

@main
struct IOSAccessAssessmentApp: App {
    @StateObject private var userState = UserStateViewModel()
    @StateObject private var workspaceViewModel = WorkspaceViewModel()
    private let authService = AuthService()
    
    init() {
        do {
            try setupTips()
        } catch {
            print("Error initializing tips: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if userState.isAuthenticated {
                if workspaceViewModel.isWorkspaceSelected {
                    SetupView()
                    .environmentObject(userState)
                    .environmentObject(workspaceViewModel)
                    .onAppear {
                        callRefreshToken()
                    }
                }
                else {
                    WorkspaceSelectionView()
                    .environmentObject(userState)
                    .environmentObject(workspaceViewModel)
                    .onAppear {
                        callRefreshToken()
                    }
                }
            } else {
                LoginView()
                    .environmentObject(userState)
            }
        }
        .onChange(of: workspaceViewModel.isWorkspaceSelected) { newValue, oldValue in
            print("Workspace selection changed: \(newValue)") // Debugging line
        }
    }
    
    private func setupTips() throws {
        // Purge all TipKit-related data.
//        try Tips.resetDatastore()
        
        // Configure and load all tips in the app.
        try Tips.configure()
    }
    
    /// TODO: Handle refresh token failure case
    private func callRefreshToken() {
        authService.callRefreshToken() { result in
            switch result {
            case .success(let authResponse):
                print("Refresh token successful")
            case .failure(let authError):
                print("Refresh token failed: \(authError.localizedDescription)")
            }
        }
    }
}
