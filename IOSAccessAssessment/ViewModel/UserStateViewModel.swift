//
//  UserStateViewModel.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 20.11.2024.
//

import Foundation

class UserStateViewModel: ObservableObject {
    
    @Published var isAuthenticated: Bool = false
    
    private let keychainService = KeychainService()
    
    init() {
        isAuthenticated = keychainService.isTokenValid()
    }
    
    func loginSuccess() {
        isAuthenticated = true
    }
    
    func logout() {
        keychainService.removeValue(for: .accessToken)
        keychainService.removeValue(for: .expirationDate)
        
        isAuthenticated = false
    }
}
