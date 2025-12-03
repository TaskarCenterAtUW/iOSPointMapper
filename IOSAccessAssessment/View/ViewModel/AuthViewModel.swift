//
//  AuthViewModel.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/2/25.
//

import SwiftUI

final class AuthViewModel: ObservableObject {
    @Published var isAuthenticated: Bool = false
    private let authService: AuthService = AuthService.shared
}
