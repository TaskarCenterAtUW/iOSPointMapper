//
//  IOSAccessAssessmentApp.swift
//  IOSAccessAssessment
//
//  Created by Sai on 1/24/24.
//

import SwiftUI
import TipKit
import PointNMapShared

enum AppConstants {
    enum Texts {
        /// Errors
        static let refreshTokenFailedMessageKey = "Failed to Refresh Token."
        
        /// Login Status Alert
        static let loginStatusAlertTitleKey = "Login Error"
        static let loginStatusAlertDismissButtonKey = "OK"
        static let loginStatusAlertLogoutButtonKey = "Log out"
        static let loginStatusAlertMessageKey = "There was an error during login:\n%@\n Please try logging in again."
    }
}

class LoginStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    
    func update(isFailed: Bool, errorMessage: String) {
        self.isFailed = isFailed
        self.errorMessage = errorMessage
    }
}

@main
struct IOSAccessAssessmentApp: App {
    @StateObject private var userState = UserStateViewModel()
    @StateObject private var workspaceViewModel = WorkspaceViewModel()
    @StateObject private var loginStatusViewModel = LoginStatusViewModel()
    
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
                    .alert(AppConstants.Texts.loginStatusAlertTitleKey, isPresented: $loginStatusViewModel.isFailed, actions: {
                        Button(AppConstants.Texts.loginStatusAlertDismissButtonKey, role: .cancel) {
                            loginStatusViewModel.update(isFailed: false, errorMessage: "")
                            userState.logout()
                        }
                    }, message: {
                        Text(String(format: NSLocalizedString(AppConstants.Texts.loginStatusAlertMessageKey, comment: ""),
                            loginStatusViewModel.errorMessage
                        ))
                    })
                }
                else {
                    WorkspaceSelectionView()
                    .environmentObject(userState)
                    .environmentObject(workspaceViewModel)
                    .onAppear {
                        callRefreshToken()
                    }
                    .alert(AppConstants.Texts.loginStatusAlertTitleKey, isPresented: $loginStatusViewModel.isFailed, actions: {
                        Button(AppConstants.Texts.loginStatusAlertDismissButtonKey, role: .cancel) {
                            loginStatusViewModel.update(isFailed: false, errorMessage: "")
                            userState.logout()
                        }
                    }, message: {
                        Text(String(format: NSLocalizedString(AppConstants.Texts.loginStatusAlertMessageKey, comment: ""),
                            loginStatusViewModel.errorMessage
                        ))
                    })
                }
            } else {
                LoginView()
                    .environmentObject(userState)
            }
        }
    }
    
    private func setupTips() throws {
        // Purge all TipKit-related data.
//        try Tips.resetDatastore()
        
        // Configure and load all tips in the app.
        try Tips.configure()
    }
    
    private func callRefreshToken() {
        Task {
            do {
                let _ = try await userState.callRefreshToken()
            } catch let error {
                DispatchQueue.main.async {
                    loginStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
                }
            }
        }
    }
    
    private func registerEnums() {
        CategoricalAttributeRegistry.registerAll()
    }
}
