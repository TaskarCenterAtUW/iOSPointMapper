//
//  APIChangesetUploadController.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreLocation

enum APIChangesetUploadError: Error, LocalizedError {
    case featureClassNotLineString(AccessibilityFeatureClass)
    case featureClassNotPolygon(AccessibilityFeatureClass)
    
    var errorDescription: String? {
        switch self {
        case .featureClassNotLineString(let featureClass):
            return "Feature class is not a line string: \(featureClass.name)"
        case .featureClassNotPolygon(let featureClass):
            return "Feature class is not a polygon: \(featureClass.name)"
        }
    }
}

/**
    This controller is responsible for handling the upload of accessibility features as OSW elements to the OSW API, and mapping the response back to the accessibility features with their new ids and other details from OSM.
 
    The general workflow for the upload is as follows:
    1. Map the accessibility features to OSW elements based on their geometry type (point, linestring, polygon). This involves creating the corresponding OSW elements (OSWPoint, OSWLineString, OSWPolygon) and preparing any additional tags or properties that need to be uploaded along with the elements.
    2. Prepare the upload operations (create, modify) for the OSW elements and perform the upload using the ChangesetService.
    3. Handle the response from the upload to get the new ids and details for the uploaded OSW elements. This involves mapping the response back to the original accessibility features using a cache that keeps track of the mapping between the original features and the OSW elements.
    4. Return the results of the upload, including the mapped accessibility features with their new ids and any failed uploads.

    - TODO: Eventually, the methods here such as featureToPoint, featureToLineString, featureToPolygon can be moved to the AccessibilityFeatureProtocol as extension methods (or a dedicated helper class) since they are responsible for mapping an accessibility feature to an OSW element, which is a core responsibility of the accessibility feature model.
 
 */
class APIChangesetUploadController: ObservableObject {
    public var idGenerator: IntIdGenerator = IntIdGenerator()
    public var capturedFrameIds: Set<UUID> = []
    
    func updateCapturedFrameIds(captureIds: Set<UUID>) {
        capturedFrameIds = capturedFrameIds.union(captureIds)
    }
    
    func uploadFeatures(
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        liveMappingData: LiveMappingData,
        inputs: APIChangesetUploadInputs
    ) async throws -> APIChangesetUploadResults {
        idGenerator = IntIdGenerator()
        var isFailedCaptureUpload = false
        if !capturedFrameIds.contains(inputs.captureData.id) {
            do {
                try await uploadCapturePoint(inputs: inputs)
            } catch {
                /// Leave it up to the caller to handle the failed capture upload
                isFailedCaptureUpload = true
            }
        }
        var apiChangesetUploadResults: APIChangesetUploadResults
        switch inputs.accessibilityFeatureClass.oswPolicy.oswElementClass.geometry {
        case .point:
            apiChangesetUploadResults = try await uploadPoints(
                accessibilityFeatures: accessibilityFeatures,
                liveMappingData: liveMappingData,
                inputs: inputs
            )
        case .linestring:
            /// For the sidewalk feature class, only upload one linestring representing the entire sidewalk, and connect it to the previously uploaded linestring
            var accessibilityFeaturesLocal = accessibilityFeatures
            var shouldConnectLast = false
            if inputs.accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk,
               let firstAccessibilityFeature = accessibilityFeatures.first {
                accessibilityFeaturesLocal = [firstAccessibilityFeature]
                shouldConnectLast = true
            }
            apiChangesetUploadResults = try await uploadLineStrings(
                accessibilityFeatures: accessibilityFeaturesLocal,
                liveMappingData: liveMappingData,
                inputs: inputs
            )
        case .polygon:
            apiChangesetUploadResults = try await uploadPolygons(
                accessibilityFeatures: accessibilityFeatures,
                liveMappingData: liveMappingData,
                inputs: inputs
            )
        }
        return APIChangesetUploadResults(
            from: apiChangesetUploadResults,
            isFailedCaptureUpload: isFailedCaptureUpload
        )
    }
    
    func uploadCapturePoint(inputs: APIChangesetUploadInputs) async throws {
        let additionalTags: [String: String] = [
            APIConstants.TagKeys.captureIdKey: inputs.captureData.id.uuidString,
            APIConstants.TagKeys.captureLatitudeKey: String(inputs.captureLocation.latitude),
            APIConstants.TagKeys.captureLongitudeKey: String(inputs.captureLocation.longitude)
        ]
        let capturePoint: OSWPoint = OSWPoint(
            id: String(idGenerator.nextId()), version: "1",
            oswElementClass: .AppAnchorNode,
            latitude: inputs.captureLocation.latitude, longitude: inputs.captureLocation.longitude,
            attributeValues: [:],
            experimentalAttributeValues: [:],
            additionalTags: additionalTags
        )
        let uploadOperation: ChangesetDiffOperation = .create(capturePoint)
        _ = try await ChangesetService.shared.performUploadAsync(
            workspaceId: inputs.workspaceId, changesetId: inputs.changesetId,
            operations: [uploadOperation],
            accessToken: inputs.accessToken
        )
        capturedFrameIds.insert(inputs.captureData.id)
    }
    
    private func getAdditionalTags(
        accessibilityFeatureClass: AccessibilityFeatureClass,
        captureData: CaptureData,
        liveMappingData: LiveMappingData,
    ) -> [String: String] {
        var enhancedAnalysisMode: Bool = false
        switch captureData {
        case .imageData(_):
            enhancedAnalysisMode = false
        case .imageAndMeshData(_):
            enhancedAnalysisMode = true
        }
        return [
            APIConstants.TagKeys.captureIdKey: captureData.id.uuidString,
            APIConstants.TagKeys.enhancedAnalysisModeKey: String(enhancedAnalysisMode)
        ]
    }
}

/**
 Extension to generalize transmission of all geometry types
 */
extension APIChangesetUploadController {
    func uploadAllFeatures(
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        liveMappingData: LiveMappingData,
        inputs: APIChangesetUploadInputs,
        shouldConnectLast: Bool = false
    ) async throws -> APIChangesetUploadResults {
        var accessibilityFeatures = accessibilityFeatures
        var totalFeatures = accessibilityFeatures.count
        guard totalFeatures > 0, let firstFeature = accessibilityFeatures.first else {
            return APIChangesetUploadResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Map Accessibility Features to OSW Elements
        let featureCache: APIChangesetUploadCache = APIChangesetUploadCache()
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: inputs.accessibilityFeatureClass,
            captureData: inputs.captureData, liveMappingData: liveMappingData
        )
        for feature in accessibilityFeatures {
            switch feature.accessibilityFeatureClass.oswPolicy.oswElementClass.geometry {
            case .point:
                let diffOperations: [ChangesetDiffOperation] = getDiffOperationsFromPointFeature(
                    feature, additionalTags: additionalTags
                )
                diffOperations.forEach { diffOperation in
                    let oswElement = diffOperation.oswElement
                    let osmOldId = oswElement.id
                    featureCache.addEntry(osmOldId: osmOldId, feature: feature, diffOperation: diffOperation)
                }
            default:
                break
            }
        }
        let uploadOperations: [ChangesetDiffOperation] = featureCache.getDiffOperations()
        guard uploadOperations.count > 0 else {
            return APIChangesetUploadResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: inputs.workspaceId, changesetId: inputs.changesetId,
            operations: uploadOperations,
            accessToken: inputs.accessToken
        )
        let uploadedOSWElements: [any OSWElement] = getUploadedOSWElements(
            from: uploadedElements, featureCache: featureCache
        )
        guard !uploadedOSWElements.isEmpty else {
            return APIChangesetUploadResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Created Mapped Accessibility Features from the uploaded OSW Elements
        /// Make sure you are using the old ids of the uploaded elements to map back to the features
        let uploadedOldToNewIdMap: [String: String] = uploadedElements.oldToNewIdMap
        let mappedAccessibilityFeatures: [MappedAccessibilityFeature] = uploadedOSWElements.compactMap { oswElement in
            let osmNewId = oswElement.id
            guard let osmOldId = uploadedOldToNewIdMap.first(where: { $0.value == osmNewId })?.key else { return nil }
            guard let matchedFeature = featureCache.getEntry(osmOldId: osmOldId)?.feature else { return nil }
            return MappedAccessibilityFeature(
                id: matchedFeature.id,
                accessibilityFeature: matchedFeature,
                oswElement: oswElement
            )
        }
        let failedUploads = totalFeatures - mappedAccessibilityFeatures.count
        return APIChangesetUploadResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            oswElements: uploadedOSWElements,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
}

/**
 Extension for feature to OSWElement logic
 */
extension APIChangesetUploadController {
    private func getDiffOperationsFromPointFeature(
        _ feature: any AccessibilityFeatureProtocol,
        additionalTags: [String: String] = [:]
    ) -> [ChangesetDiffOperation] {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .point else { return [] }
        guard var featureLocation = feature.getLastLocationCoordinate() else { return [] }
        var isExisting = false
        var id = String(idGenerator.nextId())
        var version = "1"
        /// If feature is of type editable accessibility feature, then also add the calculated attribute values as a property
        var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
        if let editableFeature = feature as? EditableAccessibilityFeature {
            calculatedAttributeValues = editableFeature.calculatedAttributeValues
        }
        /// Add location as additional tags as well
        var additionalTags = additionalTags
        additionalTags[APIConstants.TagKeys.calculatedLatitudeKey] = String(featureLocation.latitude)
        additionalTags[APIConstants.TagKeys.calculatedLongitudeKey] = String(featureLocation.longitude)
        /// If feature is of type editable accessibility feature and is existing, then use the existing id and version for the point
        /// to update the existing point in OSM instead of creating a new one
        if let editableFeature = feature as? EditableAccessibilityFeature, editableFeature.isExisting {
            guard let existingPoint = editableFeature.oswElement as? OSWPoint else { return [] }
            isExisting = true
            id = existingPoint.id
            version = existingPoint.version
            featureLocation = CLLocationCoordinate2D(latitude: existingPoint.latitude, longitude: existingPoint.longitude)
            /// Merge additional tags
            additionalTags = additionalTags.merging(existingPoint.additionalTags) { current, existing in
                return current
            }
        }
        let oswPoint = OSWPoint(
            id: id,
            version: version,
            oswElementClass: feature.accessibilityFeatureClass.oswPolicy.oswElementClass,
            latitude: featureLocation.latitude,
            longitude: featureLocation.longitude,
            attributeValues: feature.attributeValues,
            calculatedAttributeValues: calculatedAttributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            additionalTags: additionalTags
        )
        let diffOperation: ChangesetDiffOperation = isExisting ? .modify(oswPoint) : .create(oswPoint)
        return [diffOperation]
    }
    
    private func getDiffOperationsFromLinestringFeature(
        _ feature: any AccessibilityFeatureProtocol,
        additionalTags: [String: String] = [:]
    ) -> [ChangesetDiffOperation] {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .linestring else { return [] }
        guard let featureLocationElement: OSMLocationElement = feature.locationDetails?.locations.first,
              featureLocationElement.isWay, !featureLocationElement.isClosed else {
            return []
        }
        var isExisting = false
        var id = String(idGenerator.nextId())
        var version = "1"
        /// If feature is of type editable accessibility feature, then also add the calculated attribute values as a property to the linestring
        var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
        if let editableFeature = feature as? EditableAccessibilityFeature {
            calculatedAttributeValues = editableFeature.calculatedAttributeValues
        }
        var additionalTags = additionalTags
        var pointDiffOperations: [ChangesetDiffOperation] = []
        if let editableFeature = feature as? EditableAccessibilityFeature, editableFeature.isExisting {
            guard let existingLineString = editableFeature.oswElement as? OSWLineString else {
                /// If the feature is deemed to exist, but we cannot get an existing linestring for it, then we should not attempt to upload it.
                return []
            }
            isExisting = true
            id = existingLineString.id
            version = existingLineString.version
//            pointDiffOperations = existingLineString.points // Points are not being modified in the linestring upload.
            additionalTags = additionalTags.merging(existingLineString.additionalTags) { current, existing in
                return current
            }
        } else {
            featureLocationElement.coordinates.forEach { location in
                let oswPointId = String(idGenerator.nextId())
                var pointAdditionalTags: [String: String] = [:]
                pointAdditionalTags[APIConstants.TagKeys.calculatedLatitudeKey] = String(location.latitude)
                pointAdditionalTags[APIConstants.TagKeys.calculatedLongitudeKey] = String(location.longitude)
                let point = OSWPoint(
                    id: oswPointId, version: "1",
                    oswElementClass: oswElementClass,
                    latitude: location.latitude, longitude: location.longitude,
                    attributeValues: [:],
                    calculatedAttributeValues: [:],
                    experimentalAttributeValues: [:],
                    additionalTags: pointAdditionalTags
                )
                pointDiffOperations.append(.create(point))
            }
        }
        let oswLineString = OSWLineString(
            id: id,
            version: version,
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            calculatedAttributeValues: calculatedAttributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            pointRefs: pointDiffOperations.map { $0.oswElement.id },
            additionalTags: additionalTags
        )
        var diffOperation: ChangesetDiffOperation = isExisting ? .modify(oswLineString) : .create(oswLineString)
        let allDiffOperations = pointDiffOperations + [diffOperation]
        return allDiffOperations
    }
    
    private func getDiffOperationsFromPolygons(
        _ feature: any AccessibilityFeatureProtocol,
        additionalTags: [String: String] = [:]
    ) -> [ChangesetDiffOperation] {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .polygon else { return [] }
        guard let featureLocationElement: OSMLocationElement = feature.locationDetails?.locations.first,
              featureLocationElement.isWay, featureLocationElement.isClosed else {
            return []
        }
        var isExisting = false
        var id = String(idGenerator.nextId())
        var version = "1"
        /// If feature is of type editable accessibility feature, then also add the calculated attribute values as a property to the polygon
        var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
        if let editableFeature = feature as? EditableAccessibilityFeature {
            calculatedAttributeValues = editableFeature.calculatedAttributeValues
        }
        var additionalTags = additionalTags
        var pointDiffOperations: [ChangesetDiffOperation] = []
        if let editableFeature = feature as? EditableAccessibilityFeature, editableFeature.isExisting {
            guard let existingPolygon = editableFeature.oswElement as? OSWPolygon else {
                /// If the feature is deemed to exist, but we cannot get an existing polygon for it, then we should not attempt to upload it.
                return []
            }
            isExisting = true
            id = existingPolygon.id
            version = existingPolygon.version
//            pointDiffOperations = existingLineString.points // Points are not being modified in the polygon upload.
            additionalTags = additionalTags.merging(existingPolygon.additionalTags) { current, existing in
                return current
            }
        } else {
            featureLocationElement.coordinates.forEach { location in
                let oswPointId = String(idGenerator.nextId())
                var pointAdditionalTags: [String: String] = [:]
                pointAdditionalTags[APIConstants.TagKeys.calculatedLatitudeKey] = String(location.latitude)
                pointAdditionalTags[APIConstants.TagKeys.calculatedLongitudeKey] = String(location.longitude)
                let point = OSWPoint(
                    id: oswPointId, version: "1",
                    oswElementClass: oswElementClass,
                    latitude: location.latitude, longitude: location.longitude,
                    attributeValues: [:],
                    calculatedAttributeValues: [:],
                    experimentalAttributeValues: [:],
                    additionalTags: pointAdditionalTags
                )
                pointDiffOperations.append(.create(point))
            }
        }
        let oswPolygon = OSWPolygon(
            id: id,
            version: version,
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            calculatedAttributeValues: calculatedAttributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            pointRefs: pointDiffOperations.map { $0.oswElement.id },
            additionalTags: additionalTags
        )
        var diffOperation: ChangesetDiffOperation = isExisting ? .modify(oswPolygon) : .create(oswPolygon)
        let allDiffOperations = pointDiffOperations + [diffOperation]
        return allDiffOperations
    }
}


