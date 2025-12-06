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
