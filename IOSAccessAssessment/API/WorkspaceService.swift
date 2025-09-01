//
//  WorkspaceService.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/25/25.
//

import Foundation
import CoreLocation

struct Workspace: Codable, Hashable {
    let id: Int
    let type: String?
    let title: String
    let description: String
    let externalAppAccess: Int
//    let kartaViewToken: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case description
        case externalAppAccess
        //        case kartaViewToken
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        type = try? container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        externalAppAccess = try container.decode(Int.self, forKey: .externalAppAccess)
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case badStatus(Int)
    case decoding(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .invalidResponse:
            return "The response from the server is invalid."
        case .badStatus(let statusCode):
            return "Received bad status code: \(statusCode)."
        case .decoding(let error):
            return "Decoding error: \(error.localizedDescription)."
        }
    }
}

class WorkspaceService {
    static let shared = WorkspaceService()
    private init() {}
    
    private let accessToken = KeychainService().getValue(for: .accessToken)
//    public var workspaces: [Workspace] = []
    
    func fetchWorkspaces(location: CLLocationCoordinate2D, radius: Int = 2000) async throws -> [Workspace] {
        guard let url = URL(string: "\(APIConstants.Constants.baseUrl)/workspaces/mine?lat=\(location.latitude)&lon=\(location.longitude)&radius=\(radius)")
        else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.badStatus(httpResponse.statusCode)
        }
        
        do {
            let decoder = JSONDecoder()
            let workspaces = try decoder.decode([Workspace].self, from: data)
            return workspaces
        } catch {
            throw APIError.decoding(error)
        }
    }
}
