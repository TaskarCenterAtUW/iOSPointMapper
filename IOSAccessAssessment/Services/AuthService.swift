//
//  AuthService.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 08.11.2024.
//

import Foundation

enum AuthError: Error, LocalizedError {
    case invalidURL
    case noData
    case invalidResponse
    case serverError(message: String)
    case decodingError
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL."
        case .noData:
            return "No data received from the server."
        case .invalidResponse:
            return "Invalid response from the server."
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode the response from the server."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}

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
    
    private enum Constants {
        static let serverUrl = "https://tdei-gateway-stage.azurewebsites.net/api/v1/authenticate"
    }
    
    private let keychainService = KeychainService()
    
    func login(
        username: String,
        password: String,
        completion: @escaping (Result<AuthResponse, AuthError>) -> Void
    ) {
        guard let request = createRequest(username: username, password: password) else {
            completion(.failure(.invalidURL))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(.serverError(message: error.localizedDescription)))
                return
            }
            
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
    
    func logout() {
        keychainService.removeValue(for: .accessToken)
        keychainService.removeValue(for: .expirationDate)
    }
    
    private func createRequest(username: String, password: String) -> URLRequest? {
        guard let url = URL(string: Constants.serverUrl) else { return nil }
        
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

    private func handleResponse(
        data: Data,
        httpResponse: HTTPURLResponse,
        completion: @escaping (Result<AuthResponse, AuthError>) -> Void
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
        completion: @escaping (Result<AuthResponse, AuthError>) -> Void
    ) {
        do {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            storeAuthData(authResponse: authResponse)
            completion(.success(authResponse))
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
    
    private func decodeErrorResponse(
        data: Data,
        statusCode: Int,
        completion: @escaping (Result<AuthResponse, AuthError>) -> Void
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
    
}
