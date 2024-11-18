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
    
    private enum Constants {
        static let serverUrl = "https://tdei-gateway-stage.azurewebsites.net/api/v1/authenticate"
    }
    
    func authenticate(
        username: String,
        password: String,
        completion: @escaping (Result<AuthResponse, Error>) -> Void
    ) {
        guard let request = createRequest(username: username, password: password) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            
            guard let data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "Invalid response", code: 0, userInfo: nil)))
                return
            }
            
            self.handleResponse(data: data,
                                httpResponse: httpResponse,
                                completion: completion)
        }.resume()
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
        completion: @escaping (Result<AuthResponse, Error>) -> Void
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
        completion: @escaping (Result<AuthResponse, Error>) -> Void
    ) {
        do {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            completion(.success(authResponse))
        } catch {
            completion(.failure(error))
        }
    }

    private func decodeErrorResponse(
        data: Data,
        statusCode: Int,
        completion: @escaping (Result<AuthResponse, Error>) -> Void
    ) {
        do {
            let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
            let errorMessage = errorResponse.errors?.joined(separator: "\n") ?? errorResponse.message
            
            completion(.failure(NSError(domain: "Server Error",
                                        code: statusCode,
                                        userInfo: [NSLocalizedDescriptionKey: errorMessage])))
        } catch {
            completion(.failure(NSError(domain: "Unable to parse error response",
                                        code: statusCode,
                                        userInfo: nil)))
        }
    }
    
}
