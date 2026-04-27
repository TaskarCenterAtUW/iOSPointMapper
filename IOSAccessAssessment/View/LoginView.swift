//
//  LoginView.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 08.11.2024.
//

import SwiftUI

enum LoginViewConstants {
    enum Texts {
        static let loginViewTitle = "Login"
        
        /// Fields
        static let usernamePlaceholder = "Username"
        static let passwordPlaceholder = "Password"
        static let tdeiEnvironmentLabel = "TDEI Environment:"
        static let loginButtonTitle = "Login"
    }
    
    enum Images {
        static let loginIcon = "lock.shield"
    }
}

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @EnvironmentObject var userState: UserStateViewModel
    
    var body: some View {
        VStack(spacing: 30) {
            Label(LoginViewConstants.Texts.loginViewTitle, systemImage: LoginViewConstants.Images.loginIcon)
                .font(.largeTitle)
                .bold()
            
            TextField(LoginViewConstants.Texts.usernamePlaceholder, text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            SecureField(LoginViewConstants.Texts.passwordPlaceholder, text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            HStack {
                Spacer()
                Text(LoginViewConstants.Texts.tdeiEnvironmentLabel)
                Picker(LoginViewConstants.Texts.tdeiEnvironmentLabel, selection: $userState.selectedEnvironment) {
                    ForEach(APIEnvironment.allCases, id: \.self) { environment in
                        Text(environment.rawValue).tag(environment)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                Spacer()
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
                    Text(LoginViewConstants.Texts.loginButtonTitle)
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
                let _ = try await userState.login(username: username, password: password)
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            } catch let authError {
                DispatchQueue.main.async {
                    self.errorMessage = authError.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
