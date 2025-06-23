//
//  ChangesetService.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 11.11.2024.
//

import Foundation

typealias ParsedElements = (nodes: [String: [String: String]]?, ways: [String: [String: String]]?)

enum ChangesetDiffOperation {
    case create(OSMElement)
    case modify(OSMElement)
    case delete(OSMElement)
}

class ChangesetService {
    // TODO: Replace with globally available APIConstants
    private enum Constants {
        static let baseUrl = "https://osm.workspaces-stage.sidewalks.washington.edu/api/0.6"
        static let workspaceId = "288"
    }
    
    static let shared = ChangesetService()
    private init() {}
    
    private let accessToken = KeychainService().getValue(for: .accessToken)
    private(set) var changesetId: String?
    
    func openChangeset(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(Constants.baseUrl)/changeset/create"),
              let accessToken
        else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.workspaceId, forHTTPHeaderField: "X-Workspace")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        
        guard let xmlData = """
            <osm>
                <changeset>
                    <tag k="created_by" v="iOSPointMapper" />
                    <tag k="comment" v="iOS OSM client" />
                </changeset>
            </osm>
            """
            .data(using: .utf8)
        else {
            print("Failed to create XML data.")
            return
        }

        request.httpBody = xmlData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data, let changesetId = String(data: data, encoding: .utf8) {
                self.changesetId = changesetId
                completion(.success(changesetId))
            } else {
                completion(.failure(NSError(domain: "ChangesetError",
                                            code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "Failed to open changeset"])))
            }
        }.resume()
    }
    
    func performUpload(operations: [ChangesetDiffOperation], completion: @escaping (Result<ParsedElements, Error>) -> Void) {
        guard let changesetId,
              let accessToken,
              let url = URL(string: "\(Constants.baseUrl)/changeset/\(changesetId)/upload")
        else {
            completion(.failure(NSError(domain: "Invalid state", code: -2)))
            return
        }

        var createXML = ""
        var modifyXML = ""
        var deleteXML = ""

        for op in operations {
            switch op {
            case .create(let element):
                createXML += element.toOSMCreateXML(changesetId: changesetId) + "\n"
            case .modify(let element):
                modifyXML += element.toOSMModifyXML(changesetId: changesetId) + "\n"
            case .delete(let element):
                deleteXML += element.toOSMDeleteXML(changesetId: changesetId) + "\n"
            }
        }

        let osmChangeXML = """
        <osmChange version="0.6" generator="iOSPointMapper">
            \(createXML.isEmpty ? "" : "<create>\n\(createXML)</create>")
            \(modifyXML.isEmpty ? "" : "<modify>\n\(modifyXML)</modify>")
            \(deleteXML.isEmpty ? "" : "<delete>\n\(deleteXML)</delete>")
        </osmChange>
        """
//        print("XML Content: ", osmChangeXML)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.workspaceId, forHTTPHeaderField: "X-Workspace")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = osmChangeXML.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.success((nil, nil)))
                return
            }

            let parser = ChangesetXMLParser()
            parser.parse(data: data)

            completion(.success((parser.nodesWithAttributes, parser.waysWithAttributes)))
        }.resume()
    }
    
    func closeChangeset(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let changesetId, let accessToken else { return }
        
        guard let url = URL(string: "\(Constants.baseUrl)/changeset/\(changesetId)/close") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            self.changesetId = nil
            
            completion(.success(()))
        }.resume()
    }
    
}
