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
    
    func login(
        username: String, password: String,
        completion: @escaping (Result<AuthResponse, NetworkError>) -> Void
    ) {
        guard let request = createLoginRequest(username: username, password: password) else {
            completion(.failure(.invalidURL))
            return
        }
        
        performRequest(with: request, completion: completion)
    }
    
    func logout() {
        keychainService.removeValue(for: .accessToken)
        keychainService.removeValue(for: .expirationDate)
        keychainService.removeValue(for: .refreshToken)
        keychainService.removeValue(for: .refreshExpirationDate)
    }
    
    func callRefreshToken(completion: @escaping (Result<AuthResponse, NetworkError>) -> Void) {
        guard let refreshToken = keychainService.getValue(for: .refreshToken) else {
            print("No refresh token found.")
            return
        }
        
        guard let request = createRefreshRequest(refreshToken: refreshToken) else {
            print("Invalid URL for refresh token.")
            return
        }
        
        performRequest(with: request, completion: completion)
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
    
    private func performRequest(
        with request: URLRequest,
        completion: @escaping (Result<AuthResponse, NetworkError>) -> Void
    ) {
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error {
                completion(.failure(.serverError(message: error.localizedDescription)))
                return
            }
            guard let self = self else { return }
            
            guard let data else {
                completion(.failure(.noData))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }
            
            self.handleResponse(data: data,
                                httpResponse: httpResponse,
                                completion: completion)
        }.resume()
    }

    private func handleResponse(
        data: Data,
        httpResponse: HTTPURLResponse,
        completion: @escaping (Result<AuthResponse, NetworkError>) -> Void
    ) {
        if (200...299).contains(httpResponse.statusCode) {
            decodeSuccessResponse(data: data,
                                  completion: completion)
        } else {
            decodeErrorResponse(data: data,
                                statusCode: httpResponse.statusCode,
                                completion: completion)
        }
    }

    private func decodeSuccessResponse(
        data: Data,
        completion: @escaping (Result<AuthResponse, NetworkError>) -> Void
    ) {
        do {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            storeAuthData(authResponse: authResponse)
            completion(.success(authResponse))
        } catch {
            completion(.failure(.decodingError))
        }
    }
    
    private func decodeErrorResponse(
        data: Data,
        statusCode: Int,
        completion: @escaping (Result<AuthResponse, NetworkError>) -> Void
    ) {
        do {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            let errorMessage = errorResponse.message
                .appending(": ")
                .appending(errorResponse.errors?.joined(separator: "\n") ?? "")
            
            completion(.failure(.serverError(message: errorMessage)))
        } catch {
            completion(.failure(.decodingError))
        }
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
