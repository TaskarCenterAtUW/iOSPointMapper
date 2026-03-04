//
//  UserStateViewModel.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 20.11.2024.
//

import Foundation

class UserStateViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    private let authService: AuthService = AuthService.shared
        
    /**
     Enhanced Analysis enables polygon mesh creation for captured environments.
     
     - WARNING:
        TODO: The initialization of this property should be done by checking if enhanced analysis (polygon mesh creation) is available.
     
     - NOTE:
        This feature may require additional processing power and may not be available on older devices.
     */
    @Published var isEnhancedAnalysisEnabled: Bool = false
    
    /**
     Select the app mode.
     
        1. Standard Mode: Standard mode allows users to capture new data and perform mapping in real-time, providing an interactive experience.
     
        2. Test Mode: Test mode allows developers to simulate mapping by using existing locally saved input data to perform mapping without needing to capture new data.
     */
    @Published var appMode: AppMode = .standard
    
    init() {
        isAuthenticated = authService.checkTokenValid()
    }
    
    func getUsername() -> String? {
        return authService.getUsername()
    }
    
    func getAccessToken() -> String? {
        return authService.getAccessToken()
    }
    
    func loginSuccess() {
        isAuthenticated = true
    }
    
    func logout() {
        authService.logout()
        
        isAuthenticated = false
    }
}
