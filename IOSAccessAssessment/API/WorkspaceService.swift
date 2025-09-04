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
    let description: String?
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
        type = try? container.decodeIfPresent(String.self, forKey: .type) ?? "osw"
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
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
    
    func fetchWorkspaces(location: CLLocationCoordinate2D?, radius: Int = 2000) async throws -> [Workspace] {
        guard let base = URL(string: APIConstants.Constants.workspacesAPIBaseUrl),
              let accessToken
        else {
            throw APIError.invalidURL
        }
        var comps = URLComponents(url: base.appendingPathComponent("workspaces/mine"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "radius", value: "\(radius)")
        ]
        if let location = location {
            comps?.queryItems?.append(contentsOf: [
                URLQueryItem(name: "lat", value: "\(location.latitude)"),
                URLQueryItem(name: "lon", value: "\(location.longitude)")
            ])
        }
        guard let url = comps?.url else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("Requesting workspaces with URL: \(url.absoluteString)")
        
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
