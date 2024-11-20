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
    
    var body: some Scene {
        WindowGroup {
            if userState.isAuthenticated {
                SetupView()
                    .environmentObject(userState)
            } else {
                LoginView()
                    .environmentObject(userState)
            }
        }
    }
}
