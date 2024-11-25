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
    
    var body: some Scene {
        WindowGroup {
            if isAuthenticated {
                SetupView()
            } else {
                LoginView()
            }
        }
    }
}
