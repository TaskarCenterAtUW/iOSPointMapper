//
//  ChangesetService.swift
//  IOSAccessAssessment
//
//  Created by Mariana Piz on 11.11.2024.
//

import Foundation

typealias ParsedElements = (nodes: [String: [String: String]]?, ways: [String: [String: String]]?)

class ChangesetService {
    
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
    
    private func performUpload(type: String, element: OSMElement,
                               completion: @escaping (Result<ParsedElements?, Error>) -> Void) {
        guard let changesetId,
              let accessToken,
              let url = URL(string: "\(Constants.baseUrl)/changeset/\(changesetId)/upload")
        else {
            completion(.failure(NSError(domain: "Invalid state", code: -2)))
            return
        }

        var mutableElement = element
        let elementXML: String
        switch type {
        case "create": elementXML = mutableElement.toOSMCreateXML(changesetId: changesetId)
        case "modify": elementXML = mutableElement.toOSMModifyXML(changesetId: changesetId)
        default:
            completion(.failure(NSError(domain: "Invalid type", code: -3)))
            return
        }

        let xmlContent = """
        <osmChange version="0.6" generator="iOSPointMapper">
            <\(type)>
                \(elementXML)
            </\(type)>
        </osmChange>
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.workspaceId, forHTTPHeaderField: "X-Workspace")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = xmlContent.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.success(nil))
                return
            }

            let parser = ChangesetXMLParser()
            parser.parse(data: data)

            // Dynamically pick which map to return
            completion(.success((parser.nodesWithAttributes, parser.waysWithAttributes)))
        }.resume()
    }

    
    // TODO: The next 3 functions have a lot of code duplication. Refactor them.
    func createNode(nodeData: NodeData, completion: @escaping (Result<[String: [String : String]]?, Error>) -> Void) {
        guard let changesetId,
              let accessToken,
              let url = URL(string: "\(Constants.baseUrl)/changeset/\(changesetId)/upload")
        else { return }
        
        let tagElements = nodeData.tags.map { key, value in
            "<tag k=\"\(key)\" v=\"\(value)\" />"
        }.joined(separator: "\n")
        
        let xmlContent =
        """
        <osmChange version="0.6" generator="iOSPointMapper Change generator">
            <create>
                <node id="-1" lat="\(nodeData.latitude)" lon="\(nodeData.longitude)" changeset="\(changesetId)">
                    \(tagElements)
                </node>
            </create>
        </osmChange>
        """
        print("XML Content: ", xmlContent)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.workspaceId, forHTTPHeaderField: "X-Workspace")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = xmlContent.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let data = data {
                let parser = ChangesetXMLParser()
                parser.parse(data: data)
//                print("Create Node Data: ", parser.nodesWithAttributes)
                completion(.success((parser.nodesWithAttributes)))
            } else {
                completion(.success((nil)))
            }
        }.resume()
    }
    
    func createWay(wayData: WayData, completion: @escaping (Result<[String: [String : String]]?, Error>) -> Void) {
        guard let changesetId,
              let accessToken,
              let url = URL(string: "\(Constants.baseUrl)/changeset/\(changesetId)/upload")
        else { return }
        
        let tagElements = wayData.tags.map { key, value in
            "<tag k=\"\(key)\" v=\"\(value)\" />"
        }.joined(separator: "\n")
        
        let nodeRefElements = wayData.nodeRefs.map { ref in
            "<nd ref=\"\(ref)\" />"
        }.joined(separator: "\n")
        
        let xmlContent =
        """
        <osmChange version="0.6" generator="iOSPointMapper Change generator">
            <create>
                <way id="-1" changeset="\(changesetId)">
                    \(tagElements)
                    \(nodeRefElements)
                </way>
            </create>
        </osmChange>
        """
        print("XML Content: ", xmlContent)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.workspaceId, forHTTPHeaderField: "X-Workspace")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = xmlContent.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let data = data {
                let parser = ChangesetXMLParser()
                parser.parse(data: data)
//                print("Create Way Data: ", parser.waysWithAttributes)
                completion(.success((parser.waysWithAttributes)))
            } else {
                completion(.success((nil)))
            }
        }.resume()
    }
    
    func modifyWay(wayData: WayData, completion: @escaping (Result<[String: [String : String]]?, Error>) -> Void) {
        guard let changesetId,
              let accessToken,
              let url = URL(string: "\(Constants.baseUrl)/changeset/\(changesetId)/upload")
        else { return }
        
        let tagElements = wayData.tags.map { key, value in
            "<tag k=\"\(key)\" v=\"\(value)\" />"
        }.joined(separator: "\n")
        
        let nodeRefElements = wayData.nodeRefs.map { ref in
            "<nd ref=\"\(ref)\" />"
        }.joined(separator: "\n")
        
        let xmlContent =
        """
        <osmChange version="0.6" generator="iOSPointMapper Change generator">
            <modify>
                <way id="\(wayData.id)" changeset="\(changesetId)" version="\(wayData.version)">
                    \(tagElements)
                    \(nodeRefElements)
                </way>
            </modify>
        </osmChange>
        """
        print("XML Content: ", xmlContent)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.workspaceId, forHTTPHeaderField: "X-Workspace")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = xmlContent.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let data = data {
                let parser = ChangesetXMLParser()
                parser.parse(data: data)
//                print("Modify Way Data: ", parser.waysWithAttributes)
                completion(.success((parser.waysWithAttributes)))
            } else {
                completion(.success((nil)))
            }
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
