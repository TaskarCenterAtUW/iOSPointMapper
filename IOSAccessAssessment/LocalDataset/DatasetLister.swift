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
    private var workspaceId: String? = nil
    
    private var workspaceDirectory: URL? = nil
    private var changesetDirectories: [URL] = []
    
    func configure(workspaceId: String) throws {
        self.workspaceId = workspaceId
        /// Get workspace directory
        let workspaceDirectory = try DatasetLister.findDirectory(id: workspaceId)
        self.workspaceDirectory = workspaceDirectory
        self.changesetDirectories = try DatasetLister.listChangesetDirectories(workspaceDirectory: workspaceDirectory)
    }
    
    static private func findDirectory(id: String, relativeTo: URL? = nil) throws -> URL {
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
    static private func listChangesetDirectories(workspaceDirectory: URL) throws -> [URL] {
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
        return finalChangesetDirectories
    }
}
