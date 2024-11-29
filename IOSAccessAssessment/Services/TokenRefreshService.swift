//
//  TokenRefreshService.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 27.11.2024.
//

import Foundation

final class TokenRefreshService {
    
    private let keychainService = KeychainService()
    private var timer: DispatchSourceTimer?

    func startTokenRefresh() {
        guard let expirationDate = keychainService.getDate(for: .expirationDate) else { return }

        let refreshTime = expirationDate.addingTimeInterval(-60)
        let timeInterval = max(refreshTime.timeIntervalSinceNow, 0)

        timer?.cancel()
        timer = DispatchSource.makeTimerSource()
        timer?.schedule(deadline: .now() + timeInterval, repeating: .never)
        timer?.setEventHandler { [weak self] in
            self?.refreshToken { result in
                switch result {
                case .success(let authResponse):
                    AuthService().storeAuthData(authResponse: authResponse)
                    self?.startTokenRefresh()
                    print("Token refreshed successfully: \(authResponse.accessToken)")
                case .failure(let error):
                    print("Failed to refresh token: \(error.errorDescription ?? "Unknown error")")
                }
            }
        }
        timer?.resume()
    }

    func stopTokenRefresh() {
        timer?.cancel()
        timer = nil
    }

    private func refreshToken(completion: @escaping (Result<AuthResponse, NetworkError>) -> Void) {
        guard let refreshToken = keychainService.getValue(for: .refreshToken) else {
            stopTokenRefresh()
            completion(.failure(.noData))
            return
        }

        guard let url = URL(string: "https://tdei-gateway-stage.azurewebsites.net/api/v1/refresh-token") else {
            stopTokenRefresh()
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = refreshToken.data(using: .utf8)

        print("request: ", request)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                self?.stopTokenRefresh()
                completion(.failure(.serverError(message: error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                self?.stopTokenRefresh()
                completion(.failure(.invalidResponse))
                return
            }

            guard let data = data else {
                self?.stopTokenRefresh()
                completion(.failure(.noData))
                return
            }

            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                completion(.success(authResponse))
            } catch {
                self?.stopTokenRefresh()
                completion(.failure(.decodingError))
            }
        }.resume()
    }

}
