//
//  AuthService.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 08.11.2024.
//

import Foundation

struct AuthResponse: Decodable {
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let refresh_expires_in: Int
}

class AuthService {
    
    private enum Constants {
        static let serverUrl = "https://tdei-gateway-stage.azurewebsites.net/api/v1/authenticate"
    }
    
    func authenticate(username: String, password: String, completion: @escaping (Result<AuthResponse, Error>) -> Void) {
        guard let url = URL(string: Constants.serverUrl) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["username": username,
                    "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: 0, userInfo: nil)))
                return
            }
            
            do {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                completion(.success(authResponse))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
