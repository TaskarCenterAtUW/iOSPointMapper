//
//  IOSAccessAssessmentApp.swift
//  IOSAccessAssessment
//
//  Created by Sai on 1/24/24.
//

import SwiftUI

@main
struct IOSAccessAssessmentApp: App {
    @StateObject private var userState = UserStateViewModel()
    @StateObject private var workspaceViewModel = WorkspaceViewModel()
    private let authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            if userState.isAuthenticated {
//                SetupView()
                if workspaceViewModel.isWorkspaceSelected {
                    SetupView()
                    .environmentObject(userState)
                    .environmentObject(workspaceViewModel)
                    .onAppear {
                        authService.refreshToken()
                    }
                }
                else {
                    WorkspaceSelectionView()
                    .environmentObject(userState)
                    .environmentObject(workspaceViewModel)
                    .onAppear {
                        authService.refreshToken()
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
}
