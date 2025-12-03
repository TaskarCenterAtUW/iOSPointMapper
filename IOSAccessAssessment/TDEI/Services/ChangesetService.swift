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
    static let shared = ChangesetService()
    private init() {}
    
    func openChangeset(
        workspaceId: String,
        accessToken: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(APIConstants.Constants.workspacesOSMBaseUrl)/changeset/create") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(workspaceId, forHTTPHeaderField: "X-Workspace")
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
                completion(.success(changesetId))
            } else {
                completion(.failure(NSError(domain: "ChangesetError",
                                            code: -1,
                                            userInfo: [NSLocalizedDescriptionKey: "Failed to open changeset"])))
            }
        }.resume()
    }
    
    func performUpload(
        workspaceId: String, changesetId: String,
        operations: [ChangesetDiffOperation],
        accessToken: String,
        completion: @escaping (Result<ParsedElements, Error>) -> Void
    ) {
        guard let url = URL(string: "\(APIConstants.Constants.workspacesOSMBaseUrl)/changeset/\(changesetId)/upload") else {
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
        request.setValue(workspaceId, forHTTPHeaderField: "X-Workspace")
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
    
    func closeChangeset(
        changesetId: String,
        accessToken: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard let url = URL(string: "\(APIConstants.Constants.workspacesOSMBaseUrl)/changeset/\(changesetId)/close") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }
}

/**
 Async versions of the ChangesetService methods
 */
extension ChangesetService {
    /**
     Opens a changeset asynchronously.
     
     - Parameters:
        - workspaceId: The ID of the workspace where the changeset will be opened.
     
     - Returns: The ID of the opened changeset.
     */
    func openChangesetAsync(
        workspaceId: String,
        accessToken: String
    ) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            openChangeset(workspaceId: workspaceId, accessToken: accessToken) { result in
                switch result {
                case .success(let changesetId):
                    continuation.resume(returning: changesetId)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
        Performs an upload of changeset operations asynchronously.
     
        - Parameters:
              - workspaceId: The ID of the workspace where the changeset is located.
                - operations: An array of `ChangesetDiffOperation` representing the changes to be uploaded.
     
        - Returns: A tuple containing parsed nodes and ways with their attributes.
     */
    func performUploadAsync(
        workspaceId: String,
        changesetId: String,
        operations: [ChangesetDiffOperation],
        accessToken: String
    ) async throws -> ParsedElements {
        return try await withCheckedThrowingContinuation { continuation in
            performUpload(
                workspaceId: workspaceId, changesetId: changesetId, operations: operations,
                accessToken: accessToken
            ) { result in
                switch result {
                case .success(let parsedElements):
                    continuation.resume(returning: parsedElements)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /**
        Closes the current changeset asynchronously.
     */
    func closeChangesetAsync(
        changesetId: String,
        accessToken: String
    ) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            closeChangeset(changesetId: changesetId, accessToken: accessToken) { result in
                switch result {
                case .success():
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
