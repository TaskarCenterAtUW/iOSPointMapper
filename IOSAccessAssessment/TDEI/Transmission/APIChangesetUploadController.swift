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
        currentMappedFeaturesData: CurrentMappedFeaturesData,
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
        let apiChangesetUploadResults: APIChangesetUploadResults = try await uploadAllFeatures(
            accessibilityFeatures: accessibilityFeatures, currentMappedFeaturesData: currentMappedFeaturesData, inputs: inputs
        )
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
        currentMappedFeaturesData: CurrentMappedFeaturesData
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
        currentMappedFeaturesData: CurrentMappedFeaturesData,
        inputs: APIChangesetUploadInputs
    ) async throws -> APIChangesetUploadResults {
        var accessibilityFeatures = accessibilityFeatures
        var totalFeatures = accessibilityFeatures.count
        guard totalFeatures > 0, let firstFeature = accessibilityFeatures.first else {
            return APIChangesetUploadResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// For the sidewalk feature class, only upload one linestring representing the entire sidewalk
        if inputs.accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk {
            accessibilityFeatures = [firstFeature]
            totalFeatures = 1
        }
        /// Map Accessibility Features to OSW Elements
        let featureCache: APIChangesetUploadCache = APIChangesetUploadCache()
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: inputs.accessibilityFeatureClass,
            captureData: inputs.captureData, currentMappedFeaturesData: currentMappedFeaturesData,
        )
        for feature in accessibilityFeatures {
            var diffOperations: [ChangesetDiffOperation] = []
            switch feature.accessibilityFeatureClass.oswPolicy.oswElementClass.geometry {
            case .point:
                diffOperations = getDiffOperationsFromPointFeature(feature, additionalTags: additionalTags)
            case .linestring:
                diffOperations = getDiffOperationsFromLinestringFeature(feature, additionalTags: additionalTags)
            case .polygon:
                diffOperations = getDiffOperationsFromPolygons(feature, additionalTags: additionalTags)
            }
            diffOperations.forEach { diffOperation in
                let oswElement = diffOperation.oswElement
                let osmOldId = oswElement.id
                featureCache.addEntry(osmOldId: osmOldId, feature: feature, diffOperation: diffOperation)
            }
        }
        var uploadOperations: [ChangesetDiffOperation] = featureCache.getDiffOperations()
        guard uploadOperations.count > 0 else {
            return APIChangesetUploadResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// For the sidewalk class, get the previously uploaded linestring, connect it to the new linestring, and add a modify operation
        if inputs.accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk,
           let newDiffOperation = featureCache.getDiffOperations().first,
           case .create(let newOSWElement) = newDiffOperation,
           let existingMappedFeature = currentMappedFeaturesData.featuresMap[inputs.accessibilityFeatureClass]?.last,
           var existingOSWLineString = existingMappedFeature.oswElement as? OSWLineString,
           let newOSWLineString = newOSWElement as? OSWLineString,
           let newOSWStartingPointRef = newOSWLineString.pointRefs.first
        {
            existingOSWLineString.pointRefs.append(newOSWStartingPointRef)
            featureCache.addEntry(osmOldId: existingOSWLineString.id, feature: existingMappedFeature, diffOperation: .modify(existingOSWLineString))
            totalFeatures += 1
            uploadOperations.append(.modify(existingOSWLineString))
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
    
    func getUploadedOSWElements(
        from uploadedElements: OSMChangesetUploadResponseElements,
        featureCache: APIChangesetUploadCache
    ) -> [any OSWElement] {
        let cachedOSWPoints = featureCache.getOSWPoints()
        var uploadedOSWPoints: [OSWPoint?] = Array(repeating: nil, count: cachedOSWPoints.count)
        uploadedElements.nodes.forEach { uploadedNode in
            let uploadedNodeData = uploadedNode.value
            let uploadedNodeOSMOldId = uploadedNodeData.oldId
            guard let nodeIndex = cachedOSWPoints.firstIndex(where: { $0.id == uploadedNodeOSMOldId }) else {
                return
            }
            guard let matchedCachedEntry = featureCache.getEntry(osmOldId: uploadedNodeOSMOldId),
                  let matchedOriginalOSWPoint = matchedCachedEntry.diffOperation.oswElement as? OSWPoint else {
                return
            }
            let uploadedOSWPoint = OSWPoint(
                id: uploadedNodeData.newId, version: uploadedNodeData.newVersion,
                oswElementClass: matchedOriginalOSWPoint.oswElementClass,
                latitude: matchedOriginalOSWPoint.latitude, longitude: matchedOriginalOSWPoint.longitude,
                attributeValues: matchedOriginalOSWPoint.attributeValues,
                calculatedAttributeValues: matchedOriginalOSWPoint.calculatedAttributeValues,
                experimentalAttributeValues: matchedOriginalOSWPoint.experimentalAttributeValues,
                additionalTags: matchedOriginalOSWPoint.additionalTags
            )
            uploadedOSWPoints[nodeIndex] = uploadedOSWPoint
        }
        let cachedOSWLineStrings = featureCache.getOSWLineStrings()
        var uploadedOSWLineStrings: [OSWLineString?] = Array(repeating: nil, count: cachedOSWLineStrings.count)
        uploadedElements.ways.forEach { uploadedWay in
            let uploadedWayData = uploadedWay.value
            let uploadedWayOSMOldId = uploadedWayData.oldId
            guard let lineStringIndex = cachedOSWLineStrings.firstIndex(where: { $0.id == uploadedWayOSMOldId }) else {
                return
            }
            guard let matchedCachedEntry = featureCache.getEntry(osmOldId: uploadedWayOSMOldId),
                  let matchedOriginalOSWLineString = matchedCachedEntry.diffOperation.oswElement as? OSWLineString else {
                return
            }
            let uploadedOSWLineString = OSWLineString(
                id: uploadedWayData.newId, version: uploadedWayData.newVersion,
                oswElementClass: matchedOriginalOSWLineString.oswElementClass,
                attributeValues: matchedOriginalOSWLineString.attributeValues,
                calculatedAttributeValues: matchedOriginalOSWLineString.calculatedAttributeValues,
                experimentalAttributeValues: matchedOriginalOSWLineString.experimentalAttributeValues,
                pointRefs: matchedOriginalOSWLineString.pointRefs,
                additionalTags: matchedOriginalOSWLineString.additionalTags
            )
            uploadedOSWLineStrings[lineStringIndex] = uploadedOSWLineString
        }
        let cachedOSWPolygons = featureCache.getOSWPolygons()
        var uploadedOSWPolygons: [OSWPolygon?] = Array(repeating: nil, count: cachedOSWPolygons.count)
        uploadedElements.ways.forEach { uploadedWay in
            let uploadedWayData = uploadedWay.value
            let uploadedWayOSMOldId = uploadedWayData.oldId
            guard let polygonIndex = cachedOSWPolygons.firstIndex(where: { $0.id == uploadedWayOSMOldId }) else {
                return
            }
            guard let matchedCachedEntry = featureCache.getEntry(osmOldId: uploadedWayOSMOldId),
                  let matchedOriginalOSWPolygon = matchedCachedEntry.diffOperation.oswElement as? OSWPolygon else {
                return
            }
            let uploadedOSWPolygon = OSWPolygon(
                id: uploadedWayData.newId, version: uploadedWayData.newVersion,
                oswElementClass: matchedOriginalOSWPolygon.oswElementClass,
                attributeValues: matchedOriginalOSWPolygon.attributeValues,
                calculatedAttributeValues: matchedOriginalOSWPolygon.calculatedAttributeValues,
                experimentalAttributeValues: matchedOriginalOSWPolygon.experimentalAttributeValues,
                pointRefs: matchedOriginalOSWPolygon.pointRefs,
                additionalTags: matchedOriginalOSWPolygon.additionalTags
            )
            uploadedOSWPolygons[polygonIndex] = uploadedOSWPolygon
        }
        return (uploadedOSWPoints.compactMap { $0 }) +
        (uploadedOSWLineStrings.compactMap { $0 }) + (uploadedOSWPolygons.compactMap { $0 })
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
        let diffOperation: ChangesetDiffOperation = isExisting ? .modify(oswLineString) : .create(oswLineString)
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
        let diffOperation: ChangesetDiffOperation = isExisting ? .modify(oswPolygon) : .create(oswPolygon)
        let allDiffOperations = pointDiffOperations + [diffOperation]
        return allDiffOperations
    }
}


