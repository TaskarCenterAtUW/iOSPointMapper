//
//  AuthService.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 08.11.2024.
//

import Foundation

struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let refreshExpiresIn: Int
    
    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case refreshExpiresIn = "refresh_expires_in"
    }
}

struct ErrorResponse: Decodable {
    let timestamp: String
    let status: String
    let message: String
    let errors: [String]?
}

class AuthService {
    static let shared = AuthService()
    
    private let keychainService = KeychainService()
    
    func login(username: String, password: String) async throws -> AuthResponse {
        guard let request = createLoginRequest(username: username, password: password) else {
            throw NetworkError.invalidURL
        }
        return try await performRequestAsync(with: request)
    }
    
    func callRefreshToken() async throws -> AuthResponse {
        guard let refreshToken = keychainService.getValue(for: .refreshToken) else {
            throw NetworkError.noData
        }
        guard let request = createRefreshRequest(refreshToken: refreshToken) else {
            throw NetworkError.invalidURL
        }
        
        return try await performRequestAsync(with: request)
    }
    
    private func createLoginRequest(username: String, password: String) -> URLRequest? {
        guard let url = URL(string: APIConstants.Constants.tdeiCoreAuthUrl) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = [
            "username": username,
            "password": password
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        return request
    }
    
    private func createRefreshRequest(refreshToken: String) -> URLRequest? {
        guard let url = URL(string: APIConstants.Constants.tdeiCoreRefreshAuthUrl) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = refreshToken.data(using: .utf8)
        
        return request
    }
    
    private func performRequestAsync(with request: URLRequest) async throws -> AuthResponse {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            return try decodeSuccessResponseAsync(data: data)
        } else {
            try decodeErrorResponseAsync(data: data, statusCode: httpResponse.statusCode)
        }
        throw NetworkError.unknownError
    }
    
    private func decodeSuccessResponseAsync(data: Data) throws -> AuthResponse {
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        storeAuthData(authResponse: authResponse)
        return authResponse
    }
    
    private func decodeErrorResponseAsync(data: Data, statusCode: Int) throws {
        let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
        let errorMessage = errorResponse.message
            .appending(": ")
            .appending(errorResponse.errors?.joined(separator: "\n") ?? "")
        throw NetworkError.serverError(message: errorMessage)
    }
    
    func logout() {
        keychainService.removeValue(for: .accessToken)
        keychainService.removeValue(for: .expirationDate)
        keychainService.removeValue(for: .refreshToken)
        keychainService.removeValue(for: .refreshExpirationDate)
    }
    
    func storeUsername(username: String) {
        keychainService.setValue(username, for: .username)
    }
    
    private func storeAuthData(authResponse: AuthResponse) {
        keychainService.setValue(authResponse.accessToken, for: .accessToken)
        let expirationDate = Date().addingTimeInterval(TimeInterval(authResponse.expiresIn))
        keychainService.setDate(expirationDate, for: .expirationDate)
        
        keychainService.setValue(authResponse.refreshToken, for: .refreshToken)
        let refreshExpirationDate = Date().addingTimeInterval(TimeInterval(authResponse.refreshExpiresIn))
        keychainService.setDate(refreshExpirationDate, for: .refreshExpirationDate)
    }
}

/**
 Methods to access stored authentication data.
 */
extension AuthService {
    func getAccessToken() -> String? {
        keychainService.getValue(for: .accessToken)
    }
    
    func getUsername() -> String? {
        keychainService.getValue(for: .username)
    }
    
    func getExpirationDate() -> Date? {
        keychainService.getDate(for: .expirationDate)
    }
    
    func checkTokenValid() -> Bool {
        keychainService.isTokenValid()
    }
}
