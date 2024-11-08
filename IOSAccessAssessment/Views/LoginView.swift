//
//  LoginView.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 08.11.2024.
//

import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @Binding var isAuthenticated: Bool
    
    private let authService = AuthService()
    private let keychainService = KeychainService()
    
    var body: some View {
        VStack(spacing: 30) {
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            Button(action: login) {
                Text("Login")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(username.isEmpty || password.isEmpty)
        }
        .padding()
    }
    
    private func login() {
        errorMessage = nil
        
        authService.authenticate(username: username, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let response):
                    keychainService.setValue(response.accessToken, for: .accessToken)
                    let expirationDate = Date().addingTimeInterval(TimeInterval(response.expiresIn))
                    keychainService.setDate(expirationDate, for: .expirationDate)
                    
                    if let _ = keychainService.getValue(for: .accessToken),
                       let _ = keychainService.getDate(for: .expirationDate) {
                        self.isAuthenticated = true
                    }
                case .failure(let error):
                    self.errorMessage = "Login failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
