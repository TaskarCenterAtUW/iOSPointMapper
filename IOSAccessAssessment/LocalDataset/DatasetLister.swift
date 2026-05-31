//
//  DatasetLister.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import Foundation

enum DatasetListerError: Error, LocalizedError {
    case invalidAPIEnvironment
    case directoryRetrievalFailed
    case indexDataNotFound(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIEnvironment:
            return "Invalid API environment."
        case .directoryRetrievalFailed:
            return "Failed to retrieve dataset directory."
        case .indexDataNotFound(let index):
            return "Data for index \(index) not found."
        }
    }
}

struct EnvironmentDirectory: Identifiable, Comparable, Hashable {
    let url: URL
    let apiEnvironment: APIEnvironment
    
    var id: URL {
        return url
    }
    
    static func < (lhs: EnvironmentDirectory, rhs: EnvironmentDirectory) -> Bool {
        return lhs.url.lastPathComponent < rhs.url.lastPathComponent
    }
}

struct WorkspaceDirectory: Identifiable, Comparable, Hashable {
    let url: URL
    let workspaceId: String
    
    var id: URL {
        return url
    }
    
    static func < (lhs: WorkspaceDirectory, rhs: WorkspaceDirectory) -> Bool {
        return lhs.url.lastPathComponent < rhs.url.lastPathComponent
    }
}

struct ChangesetDirectory: Identifiable, Comparable, Hashable {
    let url: URL
    let changesetId: String
    
    var id: URL {
        return url
    }
    
    static func < (lhs: ChangesetDirectory, rhs: ChangesetDirectory) -> Bool {
        return lhs.url.lastPathComponent < rhs.url.lastPathComponent
    }
}

class DatasetLister: ObservableObject {
    @Published var environmentDirectories: [EnvironmentDirectory] = []
    @Published var workspaceDirectories: [WorkspaceDirectory] = []
    @Published var changesetDirectories: [ChangesetDirectory] = []
    
    @Published var selectedEnvironment: EnvironmentDirectory? = nil
    @Published var selectedWorkspace: WorkspaceDirectory? = nil
    @Published var selectedChangeset: ChangesetDirectory? = nil
    
    func configure() throws {
        self.environmentDirectories = try DatasetLister.listEnvironmentDirectories()
//        self.workspaceDirectories = try DatasetLister.listWorkspaceDirectories()
    }
    
    func selectEnvironment(environmentDirectory: EnvironmentDirectory) throws {
        self.selectedEnvironment = environmentDirectory
        self.workspaceDirectories = try DatasetLister.listWorkspaceDirectories(environmentDirectory: environmentDirectory)
    }
    
    /**
     Finds all the environment directories within the app's document directory
     
     An environment directory is a string-named directory within the document directory, whose string name matches a specific API environment key.
        Each environment directory is expected to contain at least one workspace directory, which is a number-named directory containing data for a specific workspace.
     */
    static func listEnvironmentDirectories() throws -> [EnvironmentDirectory] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw DatasetListerError.directoryRetrievalFailed
        }
        let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        var environmentDirectories: [EnvironmentDirectory] = contents.filter { content in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: content.path, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue && APIEnvironment(rawValue: content.lastPathComponent) != nil
        }.compactMap { content in
            if let apiEnvironment = APIEnvironment(rawValue: content.lastPathComponent) {
                return EnvironmentDirectory(url: content, apiEnvironment: apiEnvironment)
            } else {
                return nil
            }
        }
        environmentDirectories.sort()
        return environmentDirectories
    }
    
    
    func selectWorkspace(workspaceDirectory: WorkspaceDirectory) throws {
        self.selectedWorkspace = workspaceDirectory
        self.changesetDirectories = try self.listChangesetDirectories(workspaceDirectory: workspaceDirectory)
    }
    
//    static func listWorkspaceDirectories() throws -> [URL] {
//        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
//            throw DatasetListerError.directoryRetrievalFailed
//        }
//        let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
//        var workspaceDirectories = contents.filter { content in
//            var isDirectory: ObjCBool = false
//            let exists = FileManager.default.fileExists(atPath: content.path, isDirectory: &isDirectory)
//            return exists && isDirectory.boolValue && content.lastPathComponent.allSatisfy { $0.isNumber }
//        }
//        workspaceDirectories = workspaceDirectories.sorted { $0.lastPathComponent < $1.lastPathComponent }
//        return workspaceDirectories
//    }
    static func listWorkspaceDirectories(environmentDirectory: EnvironmentDirectory) throws -> [WorkspaceDirectory] {
        let contents = try FileManager.default.contentsOfDirectory(at: environmentDirectory.url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        var workspaceDirectories = contents.filter { content in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: content.path, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue && content.lastPathComponent.allSatisfy { $0.isNumber }
        }.compactMap { content in
            let workspaceId = content.lastPathComponent
            return WorkspaceDirectory(url: content, workspaceId: workspaceId)
        }
        workspaceDirectories.sort()
        return workspaceDirectories
    }
    
    private func findDirectory(id: String, relativeTo: URL? = nil) throws -> URL {
        var relativeTo = relativeTo
        if relativeTo == nil {
            guard let relativeToUrl = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first else {
                throw DatasetListerError.directoryRetrievalFailed
            }
            relativeTo = relativeToUrl
        }
        let directory = URL(filePath: id, directoryHint: .isDirectory, relativeTo: relativeTo)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw DatasetListerError.directoryRetrievalFailed
        }
        return directory
    }
    
    /**
     Finds all the changeset directories within the workspace directory
     
     Changesets are number-named directories within the workspace directory, each containing data for a specific changeset.
     Each changeset directory is expected to contain an rgb directory, within which there is at least one .png file.
     */
    private func listChangesetDirectories(workspaceDirectory: WorkspaceDirectory) throws -> [ChangesetDirectory] {
        let contents = try FileManager.default.contentsOfDirectory(at: workspaceDirectory.url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let changesetDirectories = contents.filter { content in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: content.path, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue && content.lastPathComponent.allSatisfy { $0.isNumber }
        }.compactMap { content in
            let changesetId = content.lastPathComponent
            return ChangesetDirectory(url: content, changesetId: changesetId)
        }
        var finalChangesetDirectories: [ChangesetDirectory] = []
        for changesetDirectory in changesetDirectories {
            let rgbDirectory = changesetDirectory.url.appending(path: "rgb", directoryHint: .isDirectory)
            if FileManager.default.fileExists(atPath: rgbDirectory.path) {
                let pngFiles = try FileManager.default.contentsOfDirectory(at: rgbDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter { $0.pathExtension.lowercased() == "png" }
                if !pngFiles.isEmpty {
                    finalChangesetDirectories.append(changesetDirectory)
                }
            }
        }
        finalChangesetDirectories.sort()
        return finalChangesetDirectories
    }
    
    func selectChangeset(changesetDirectory: ChangesetDirectory) {
        self.selectedChangeset = changesetDirectory
    }
}
