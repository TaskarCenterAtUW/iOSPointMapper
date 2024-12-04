//
//  TokenRefreshService.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 27.11.2024.
//

import Foundation

final class TokenRefreshService {
    
    private let keychainService = KeychainService()

    func refreshToken() {
        guard let refreshToken = keychainService.getValue(for: .refreshToken) else {
            print("No refresh token found.")
            return
        }
        
        sendRefreshTokenRequest(refreshToken: refreshToken) { [weak self] result in
            switch result {
            case .success(let authResponse):
                self?.keychainService.storeAuthData(authResponse: authResponse)
            case .failure(let error):
                print("Failed to refresh token: \(error)")
            }
        }
    }
    
    private func sendRefreshTokenRequest(
        refreshToken: String,
        completion: @escaping (Result<AuthResponse, NetworkError>) -> Void
    ) {
        guard let url = URL(string: "https://tdei-gateway-stage.azurewebsites.net/api/v1/refresh-token") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = refreshToken.data(using: .utf8)

        print("request: ", request)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.serverError(message: error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                completion(.success(authResponse))
            } catch {
                completion(.failure(.decodingError))
            }
        }.resume()
    }

}
