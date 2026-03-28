//
//  APITransmissionHelpers.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/9/26.
//

import SwiftUI
import CoreLocation

struct APIFeatureCacheEntry: @unchecked Sendable {
    let osmOldId: String
    let feature: (any AccessibilityFeatureProtocol)?
    let oswElement: any OSWElement
}

class APIFeatureCache {
    /// OSM old ID to APIFeatureCacheEntry
    var cacheEntry: [APIFeatureCacheEntry]
    
    init() {
        self.cacheEntry = []
    }
    
    func getIndexOf(osmOldId: String) -> Int? {
        return cacheEntry.firstIndex { $0.osmOldId == osmOldId }
    }
    
    func getEntry(osmOldId: String) -> APIFeatureCacheEntry? {
        return cacheEntry.first { $0.osmOldId == osmOldId }
    }
    
    func addEntry(osmOldId: String, feature: (any AccessibilityFeatureProtocol)?, oswElement: any OSWElement) {
        let entry = APIFeatureCacheEntry(osmOldId: osmOldId, feature: feature, oswElement: oswElement)
        cacheEntry.append(entry)
    }
    
    func getOSWElements() -> [any OSWElement] {
        return cacheEntry.map { $0.oswElement }
    }
    
    func getOSWPoints() -> [OSWPoint] {
        return cacheEntry.compactMap { entry in
            if let point = entry.oswElement as? OSWPoint {
                return point
            }
            return nil
        }
    }
    
    func getOSWLineStrings() -> [OSWLineString] {
        return cacheEntry.compactMap { entry in
            if let lineString = entry.oswElement as? OSWLineString {
                return lineString
            }
            return nil
        }
    }
    
    func getOSWPolygons() -> [OSWPolygon] {
        return cacheEntry.compactMap { entry in
            if let polygon = entry.oswElement as? OSWPolygon {
                return polygon
            }
            return nil
        }
    }
}

struct APITransmissionInputs {
    let workspaceId: String
    let changesetId: String
    let accessibilityFeatureClass: AccessibilityFeatureClass
    let captureData: CaptureData
    let captureLocation: CLLocationCoordinate2D
    let accessToken: String
    let environment: APIEnvironment?
}

struct APITransmissionResults: @unchecked Sendable {
    let accessibilityFeatures: [MappedAccessibilityFeature]?
    
    let failedFeatureUploads: Int
    let totalFeatureUploads: Int
    
    let isFailedCaptureUpload: Bool
    
    init(
        accessibilityFeatures: [MappedAccessibilityFeature],
        activeFeatures: [MappedAccessibilityFeature]? = nil,
        failedFeatureUploads: Int = 0, totalFeatureUploads: Int = 0,
        isFailedCaptureUpload: Bool = false
    ) {
        self.accessibilityFeatures = accessibilityFeatures
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
        self.isFailedCaptureUpload = isFailedCaptureUpload
    }
    
    init(failedFeatureUploads: Int, totalFeatureUploads: Int) {
        self.accessibilityFeatures = nil
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
        self.isFailedCaptureUpload = false
    }
    
    /// Clone method for overwriting isFailedCaptureUpload
    init(from other: APITransmissionResults, isFailedCaptureUpload: Bool) {
        self.accessibilityFeatures = other.accessibilityFeatures
        self.failedFeatureUploads = other.failedFeatureUploads
        self.totalFeatureUploads = other.totalFeatureUploads
        self.isFailedCaptureUpload = isFailedCaptureUpload
    }
}

class IntIdGenerator {
    private var currentId: Int
    
    init(startingId: Int = 0) {
        self.currentId = startingId
    }
    
    func nextId() -> Int {
        currentId -= 1
        return currentId
    }
}
