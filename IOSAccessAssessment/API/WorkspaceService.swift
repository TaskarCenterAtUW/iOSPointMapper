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
    
    
}

class WorkspaceService {
    static let shared = WorkspaceService()
    private init() {}
    
    private let accessToken = KeychainService().getValue(for: .accessToken)
    public var workspaces: [Workspace] = []
    
    func fetchWorkspaces(location: CLLocationCoordinate2D, radius: Int = 2000, completion: @escaping (Result<[Workspace], Error>) -> Void) {
        guard let url = URL(string: "\(APIConstants.Constants.baseUrl)/workspaces/mine?lat=\(location.latitude)&lon=\(location.longitude)&radius=\(radius)")
        else {
            completion(.failure(NSError(domain: "Invalid location details", code: -2)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data {
                
            }
        }
    }
}
