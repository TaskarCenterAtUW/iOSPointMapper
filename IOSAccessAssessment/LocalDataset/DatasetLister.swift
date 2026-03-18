//
//  DatasetLister.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import Foundation

enum DatasetListerError: Error, LocalizedError {
    
}

class DatasetLister {
    var workspaceDirectories: [URL] = []
    
    private var workspaceId: String? = nil
    private var workspaceDirectory: URL? = nil
    
    var changesetDirectories: [URL] = []
    
    func configure() throws {
        self.workspaceDirectories = try DatasetLister.listWorkspaceDirectories()
    }
    
    func selectWorkspace(workspaceId: String) throws {
        self.workspaceId = workspaceId
        /// Get workspace directory
        let workspaceDirectory = try self.findDirectory(id: workspaceId)
        self.workspaceDirectory = workspaceDirectory
        self.changesetDirectories = try self.listChangesetDirectories(workspaceDirectory: workspaceDirectory)
    }
    
    /**
        Finds all workspace directories within the app's document directory.
     
        A workspace directory is a number-named directory within the document directory, containing data for a specific workspace.
        Each workspace directory is expected to contain at least one changeset directory, which is a number-named directory containing data for a specific changeset.
     */
    static func listWorkspaceDirectories() throws -> [URL] {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw DatasetDecoderError.directoryRetrievalFailed
        }
        let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        var workspaceDirectories = contents.filter { content in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: content.path, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue && content.lastPathComponent.allSatisfy { $0.isNumber }
        }
        workspaceDirectories = workspaceDirectories.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return workspaceDirectories
    }
    
    private func findDirectory(id: String, relativeTo: URL? = nil) throws -> URL {
        var relativeTo = relativeTo
        if relativeTo == nil {
            guard let relativeToUrl = FileManager.default.urls(for:.documentDirectory, in: .userDomainMask).first else {
                throw DatasetDecoderError.directoryRetrievalFailed
            }
            relativeTo = relativeToUrl
        }
        let directory = URL(filePath: id, directoryHint: .isDirectory, relativeTo: relativeTo)
        guard FileManager.default.fileExists(atPath: directory.path) else {
            throw DatasetDecoderError.directoryRetrievalFailed
        }
        return directory
    }
    
    /**
     Finds all the changeset directories within the workspace directory
     
     Changesets are number-named directories within the workspace directory, each containing data for a specific changeset.
     Each changeset directory is expected to contain an rgb directory, within which there is at least one .png file.
     */
    private func listChangesetDirectories(workspaceDirectory: URL) throws -> [URL] {
        let contents = try FileManager.default.contentsOfDirectory(at: workspaceDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let changesetDirectories = contents.filter { content in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: content.path, isDirectory: &isDirectory)
            return exists && isDirectory.boolValue && content.lastPathComponent.allSatisfy { $0.isNumber }
        }
        var finalChangesetDirectories: [URL] = []
        for changesetDirectory in changesetDirectories {
            let rgbDirectory = changesetDirectory.appending(path: "rgb", directoryHint: .isDirectory)
            if FileManager.default.fileExists(atPath: rgbDirectory.path) {
                let pngFiles = try FileManager.default.contentsOfDirectory(at: rgbDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter { $0.pathExtension.lowercased() == "png" }
                if !pngFiles.isEmpty {
                    finalChangesetDirectories.append(changesetDirectory)
                }
            }
        }
        finalChangesetDirectories = finalChangesetDirectories.sorted { $0.lastPathComponent < $1.lastPathComponent }
        return finalChangesetDirectories
    }
}
