//
//  APITransmissionHelpers.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/9/26.
//

import SwiftUI
import CoreLocation
import PointNMapShared

struct APIChangesetUploadCacheEntry: @unchecked Sendable {
    let osmOldId: String
    let feature: (any AccessibilityFeatureProtocol)?
//    let oswElement: any OSWElement
//    let isExisting: Bool
    let diffOperation: ChangesetDiffOperation
}

class APIChangesetUploadCacheEntryList {
    var entries: [APIChangesetUploadCacheEntry]
    
    init() {
        self.entries = []
    }
    
    func getIndexOf(osmOldId: String) -> Int? {
        return entries.firstIndex { $0.osmOldId == osmOldId }
    }
    
    func getEntry(osmOldId: String) -> APIChangesetUploadCacheEntry? {
        return entries.first { $0.osmOldId == osmOldId }
    }
    
    func addEntry(
        osmOldId: String, feature: (any AccessibilityFeatureProtocol)?, diffOperation: ChangesetDiffOperation
    ) {
        let entry = APIChangesetUploadCacheEntry(osmOldId: osmOldId, feature: feature, diffOperation: diffOperation)
        entries.append(entry)
    }
    
    func getDiffOperations() -> [ChangesetDiffOperation] {
        return entries.map { $0.diffOperation }
    }
    
    func getOSWPoints() -> [OSWPoint] {
        return entries.compactMap { entry in
            if let point = entry.diffOperation.oswElement as? OSWPoint {
                return point
            }
            return nil
        }
    }
    
    func getOSWPointDiffOperations() -> [ChangesetDiffOperation] {
        return entries.compactMap { entry in
            if entry.diffOperation.oswElement is OSWPoint {
                return entry.diffOperation
            }
            return nil
        }
    }
    
    func getOSWLineStrings() -> [OSWLineString] {
        return entries.compactMap { entry in
            if let lineString = entry.diffOperation.oswElement as? OSWLineString {
                return lineString
            }
            return nil
        }
    }
    
    func getOSWLineStringDiffOperations() -> [ChangesetDiffOperation] {
        return entries.compactMap { entry in
            if entry.diffOperation.oswElement is OSWLineString {
                return entry.diffOperation
            }
            return nil
        }
    }
    
    func getOSWPolygons() -> [OSWPolygon] {
        return entries.compactMap { entry in
            if let polygon = entry.diffOperation.oswElement as? OSWPolygon {
                return polygon
            }
            return nil
        }
    }
    
    func getOSWPolygonDiffOperations() -> [ChangesetDiffOperation] {
        return entries.compactMap { entry in
            if entry.diffOperation.oswElement is OSWPolygon {
                return entry.diffOperation
            }
            return nil
        }
    }
    
    /// TODO: Not used currently, but can be used in future if we support multi-polygons
//    func getOSWMultiPolygons() -> [OSWMultiPolygon] {
//        return entries.compactMap { entry in
//            if let multiPolygon = entry.oswElement as? OSWMultiPolygon {
//                return multiPolygon
//            }
//            return nil
//        }
//    }
}

class APIChangesetUploadCache {
    /// OSM old ID to APIChangesetUploadCacheEntry
    var mainEntryList: APIChangesetUploadCacheEntryList
    var auxEntryList: APIChangesetUploadCacheEntryList
    
    init() {
        self.mainEntryList = APIChangesetUploadCacheEntryList()
        self.auxEntryList = APIChangesetUploadCacheEntryList()
    }
    
    func getAllDiffOperations() -> [ChangesetDiffOperation] {
        return mainEntryList.getDiffOperations() + auxEntryList.getDiffOperations()
    }
}

struct APIChangesetUploadInputs {
    let workspaceId: String
    let changesetId: String
    let accessibilityFeatureClass: AccessibilityFeatureClass
    let captureData: CaptureData
    let captureLocation: CLLocationCoordinate2D
    let accessToken: String
    let environment: APIEnvironment?
}

struct APIChangesetUploadResults: @unchecked Sendable {
    let accessibilityFeatures: [MappedAccessibilityFeature]?
    let oswElements: [any OSWElement]?
    
    let failedFeatureUploads: Int
    let totalFeatureUploads: Int
    
    let isFailedCaptureUpload: Bool
    
    init(
        accessibilityFeatures: [MappedAccessibilityFeature],
        oswElements: [any OSWElement],
        failedFeatureUploads: Int = 0, totalFeatureUploads: Int = 0,
        isFailedCaptureUpload: Bool = false
    ) {
        self.accessibilityFeatures = accessibilityFeatures
        self.oswElements = oswElements
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
        self.isFailedCaptureUpload = isFailedCaptureUpload
    }
    
    init(failedFeatureUploads: Int, totalFeatureUploads: Int) {
        self.accessibilityFeatures = nil
        self.oswElements = nil
        self.failedFeatureUploads = failedFeatureUploads
        self.totalFeatureUploads = totalFeatureUploads
        self.isFailedCaptureUpload = false
    }
    
    /// Clone method for overwriting isFailedCaptureUpload
    init(from other: APIChangesetUploadResults, isFailedCaptureUpload: Bool) {
        self.accessibilityFeatures = other.accessibilityFeatures
        self.oswElements = other.oswElements
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
