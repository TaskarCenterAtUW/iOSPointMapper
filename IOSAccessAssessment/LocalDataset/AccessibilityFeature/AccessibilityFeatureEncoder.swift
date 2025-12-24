//
//  AccessibilityFeatureEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/23/25.
//

import Foundation

enum AccessibilityFeatureEncoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create feature data file."
        case .dataWriteFailed:
            return "Failed to write feature data to file."
        }
    }
}

final class AccessibilityFeatureFile {
    private let url: URL

    private var snapshot: AccessibilityFeatureSnapshot
    
    init(url: URL, frameNumber: UUID, timestamp: TimeInterval, feature: EditableAccessibilityFeature) throws {
        self.url = url
        
        if FileManager.default.fileExists(atPath: url.path) {
            /// Load existing snapshot
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let featureSnapshot = try decoder.decode(AccessibilityFeatureSnapshot.self, from: data)
            self.snapshot = featureSnapshot
        } else {
            let featureSnapshot = AccessibilityFeatureSnapshot(from: feature)
            self.snapshot = featureSnapshot
        }
        try self.update(frameNumber: frameNumber, timestamp: timestamp, feature: feature)
    }
    
    func update(frameNumber: UUID, timestamp: TimeInterval, feature: any AccessibilityFeatureProtocol) throws {
        self.snapshot.update(frame: frameNumber, timestamp: timestamp)
        if let editableFeature = feature as? EditableAccessibilityFeature {
            self.snapshot.update(from: editableFeature)
        } else if let mappedFeature = feature as? MappedAccessibilityFeature {
            self.snapshot.update(from: mappedFeature)
        } else {
            print("Unsupported feature type for update: \(type(of: feature))")
        }
        try self.flush()
    }
    
    func flush() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(snapshot)

        let tmpURL = url.appendingPathExtension("tmp")
        try data.write(to: tmpURL, options: [.atomic])

        _ = try FileManager.default.replaceItemAt(
            url,
            withItemAt: tmpURL,
            backupItemName: nil,
            options: .usingNewMetadataOnly
        )
    }
}

class AccessibilityFeatureEncoder {
    private let baseDirectory: URL
    private var fileStore: [UUID: AccessibilityFeatureFile] = [:]
    
    init(outDirectory: URL) throws {
        self.baseDirectory = outDirectory
        try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    func insert(features: [EditableAccessibilityFeature], frameNumber: UUID, timestamp: TimeInterval) throws {
        try features.forEach { feature in
            if let featureFile = self.fileStore[feature.id] {
                /// Update existing file
                try featureFile.update(frameNumber: frameNumber, timestamp: timestamp, feature: feature)
            } else {
                /// Create new file
                let featureFileURL = self.baseDirectory
                    .appendingPathComponent(feature.id.uuidString, isDirectory: false)
                    .appendingPathExtension("json")
                let newFeatureFile = try AccessibilityFeatureFile(
                    url: featureFileURL,
                    frameNumber: frameNumber,
                    timestamp: timestamp,
                    feature: feature
                )
                self.fileStore[feature.id] = newFeatureFile
            }
        }
    }
    
    func update(features: [any AccessibilityFeatureProtocol], frameNumber: UUID, timestamp: TimeInterval) throws {
        try features.forEach { feature in
            if let featureFile = self.fileStore[feature.id] {
                /// Update existing file
                try featureFile.update(frameNumber: frameNumber, timestamp: timestamp, feature: feature)
            } else if let editableFeature = feature as? EditableAccessibilityFeature {
                /// Create new file for editable feature
                let featureFileURL = self.baseDirectory
                    .appendingPathComponent(editableFeature.id.uuidString, isDirectory: false)
                    .appendingPathExtension("json")
                let newFeatureFile = try AccessibilityFeatureFile(
                    url: featureFileURL,
                    frameNumber: frameNumber,
                    timestamp: timestamp,
                    feature: editableFeature
                )
                self.fileStore[editableFeature.id] = newFeatureFile
            } else {
                print("Unsupported feature type for creation: \(type(of: feature))")
            }
        }
    }
    
    func done() throws {
        for (_, featureFile) in fileStore {
            try featureFile.flush()
        }
        self.fileStore.removeAll()
    }
}
