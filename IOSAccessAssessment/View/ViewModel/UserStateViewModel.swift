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
