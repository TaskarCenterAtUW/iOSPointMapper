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

final class AccessibilityFeatureFileStore {
    private let url: URL

    private var state: AccessibilityFeatureFile

    init(url: URL) throws {
        self.url = url
        let data = try Data(contentsOf: url)
        self.state = try JSONDecoder().decode(AccessibilityFeatureFile.self, from: data)
    }

    func insert(features: [EditableAccessibilityFeature]) throws {
        let featureSnapshots = features.map { AccessibilityFeatureSnapshot(from: $0) }
        self.state.accessibilityFeatures.append(contentsOf: featureSnapshots)
        try self.flush()
    }

    func update(features: [any AccessibilityFeatureProtocol]) throws {
        features.forEach { feature in
            guard let index = self.state.accessibilityFeatures.firstIndex(where: { $0.id == feature.id }) else {
                if let editableFeature = feature as? EditableAccessibilityFeature {
                    let featureSnapshot = AccessibilityFeatureSnapshot(from: editableFeature)
                    self.state.accessibilityFeatures.append(featureSnapshot)
                }
                return
            }
            var featureSnapshot = self.state.accessibilityFeatures[index]
            /// Check if feature is EditableAccessibilityFeature or MappedAccessibilityFeature
            if let editableFeature = feature as? EditableAccessibilityFeature {
                featureSnapshot.update(from: editableFeature)
            } else if let mappedFeature = feature as? MappedAccessibilityFeature {
                featureSnapshot.update(from: mappedFeature)
            } else {
                print("Unsupported feature type for update: \(type(of: feature))")
            }
            self.state.accessibilityFeatures[index] = featureSnapshot
        }
        try self.flush()
    }
    
    func flush() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(state)

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
    private var fileStores: [UUID: AccessibilityFeatureFileStore] = [:]
    
    init(outDirectory: URL) throws {
        self.baseDirectory = outDirectory
        try FileManager.default.createDirectory(at: outDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    func save(frameNumber: UUID, timestamp: TimeInterval) throws {
        let frame = String(frameNumber.uuidString)
        let accessibilityFeatureFile = AccessibilityFeatureFile(
            frame: frame,
            timestamp: timestamp,
            accessibilityFeatures: []
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(accessibilityFeatureFile)
        let path = self.baseDirectory.absoluteURL
            .appendingPathComponent(frame, isDirectory: false)
            .appendingPathExtension("json")
        try data.write(to: path)
        let fileStore = try AccessibilityFeatureFileStore(url: path)
        self.fileStores[frameNumber] = fileStore
    }
    
    func insert(features: [EditableAccessibilityFeature], frameNumber: UUID, timestamp: TimeInterval) throws {
        guard let fileStore = self.fileStores[frameNumber] else {
            throw AccessibilityFeatureEncoderError.fileCreationFailed
        }
        try fileStore.insert(features: features)
    }
    
    func update(features: [any AccessibilityFeatureProtocol], frameNumber: UUID, timestamp: TimeInterval) throws {
        guard let fileStore = self.fileStores[frameNumber] else {
            throw AccessibilityFeatureEncoderError.fileCreationFailed
        }
        try fileStore.update(features: features)
    }
}
