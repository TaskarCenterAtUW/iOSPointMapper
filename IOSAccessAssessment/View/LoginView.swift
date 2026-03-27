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
    @State private var isLoading: Bool = false
    @EnvironmentObject var userState: UserStateViewModel
    
    private let authService = AuthService.shared
    
    var body: some View {
        VStack(spacing: 30) {
            Label("Login", systemImage: "lock.shield")
                .font(.largeTitle)
                .bold()
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            Menu {
                ForEach(APIEnvironment.allCases, id: \.self) { environment in
                    Text(environment.rawValue)
                }
            }
            label: {
                Text("TDEI: \(APIEnvironment.default.rawValue)")
                    .foregroundStyle(.blue)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Button(action: login) {
                    Text("Login")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
                .disabled(username.isEmpty || password.isEmpty)
            }
        }
        .padding()
        .frame(maxWidth: 500)
//        .preferredColorScheme(.dark)
    }
    
    private func login() {
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                let _ = try await authService.loginAsync(username: username, password: password)
                authService.storeUsername(username: username)
                if let _ = authService.getAccessToken(),
                   let _ = authService.getExpirationDate() {
                    userState.loginSuccess()
                } else {
                    self.errorMessage = "Failed to retrieve access token or expiration date."
                }
            } catch let authError {
                self.errorMessage = authError.localizedDescription
            }
        }
    }
}
