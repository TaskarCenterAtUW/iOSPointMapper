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
    private var idGenerator: IntIdGenerator = IntIdGenerator()
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
            apiChangesetUploadResults = try await uploadLineStrings(
                accessibilityFeatures: accessibilityFeatures,
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
 Extension for methods to handle points transmission
 */
extension APIChangesetUploadController {
    func uploadPoints(
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        liveMappingData: LiveMappingData,
        inputs: APIChangesetUploadInputs
    ) async throws -> APIChangesetUploadResults {
        let accessibilityFeatures = accessibilityFeatures
        let totalFeatures = accessibilityFeatures.count
        /// Map Accessibility Features to OSW Elements
        let featureCache: APIChangesetUploadCache = APIChangesetUploadCache()
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: inputs.accessibilityFeatureClass,
            captureData: inputs.captureData, liveMappingData: liveMappingData
        )
        for feature in accessibilityFeatures {
            let oswElementWithStatus = featureToPointWithStatus(feature, additionalTags: additionalTags)
            guard let oswElement = oswElementWithStatus?.oswElement else { continue }
            let osmOldId = oswElement.id
            featureCache.addEntry(
                osmOldId: osmOldId, feature: feature, oswElement: oswElement,
                isExisting: oswElementWithStatus?.isExisting ?? false
            )
        }
        /// Prepare upload operations from the OSW Elements, and perform upload
        let uploadOperations: [ChangesetDiffOperation] = featureCache.getOSWElementsWithStatus().map {
            return $0.isExisting ? .modify($0.oswElement) : .create($0.oswElement)
        }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: inputs.workspaceId, changesetId: inputs.changesetId,
            operations: uploadOperations,
            accessToken: inputs.accessToken
        )
        guard featureCache.getOSWPoints().count > 0 else {
            return APIChangesetUploadResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements response
        let uploadedOSWElements = getUploadedOSWPoints(from: uploadedElements, featureCache: featureCache)
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
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToPointWithStatus(
        _ feature: any AccessibilityFeatureProtocol,
        additionalTags: [String: String] = [:]
    ) -> OSWElementWithStatus? {
        guard var featureLocation = feature.getLastLocationCoordinate() else {
            return nil
        }
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
            guard let existingPoint = editableFeature.oswElement as? OSWPoint else {
                return nil
            }
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
        return OSWElementWithStatus(oswElement: oswPoint, isExisting: isExisting)
    }
    
    private func getUploadedOSWPoints(
        from uploadedElements: OSMChangesetUploadResponseElements,
        featureCache: APIChangesetUploadCache
    ) -> [OSWPoint] {
        let cachedOSWPoints = featureCache.getOSWPoints()
        var uploadedOSWPoints: [OSWPoint?] = Array(repeating: nil, count: cachedOSWPoints.count)
        uploadedElements.nodes.forEach { uploadedNode in
            let uploadedNodeData = uploadedNode.value
            let uploadedNodeOSMOldId = uploadedNodeData.oldId
            guard let nodeIndex = cachedOSWPoints.firstIndex(where: { $0.id == uploadedNodeOSMOldId }) else {
                return
            }
            guard let matchedCachedEntry = featureCache.getEntry(osmOldId: uploadedNodeOSMOldId),
                  let matchedOriginalOSWPoint = matchedCachedEntry.oswElement as? OSWPoint else {
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
        return uploadedOSWPoints.compactMap { $0 }
    }
}

/**
 Extension to handle line string transmission
 */
extension APIChangesetUploadController {
    func uploadLineStrings(
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        liveMappingData: LiveMappingData,
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
            captureData: inputs.captureData, liveMappingData: liveMappingData
        )
        for feature in accessibilityFeatures {
            let oswElementWithStatus = featureToLineStringWithStatus(feature, additionalTags: additionalTags)
            guard let oswElement = oswElementWithStatus?.oswElement else { continue }
            let osmOldId = oswElement.id
            featureCache.addEntry(
                osmOldId: osmOldId, feature: feature, oswElement: oswElement,
                isExisting: oswElementWithStatus?.isExisting ?? false
            )
        }
        /// Prepare upload operations from the OSW Elements, and perform upload
        var uploadOperations: [ChangesetDiffOperation] = featureCache.getOSWElementsWithStatus().map {
            return $0.isExisting ? .modify($0.oswElement) : .create($0.oswElement)
        }
        /// For the sidewalk class, get the previously uploaded linestring, connect it to the new linestring, and add a modify operation
        if inputs.accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk,
           let newOSWElementWithStatus = featureCache.getOSWElementsWithStatus().first,
           !newOSWElementWithStatus.isExisting,
           let existingMappedFeature = liveMappingData.featuresMap[inputs.accessibilityFeatureClass]?.last,
           var existingOSWLineString = existingMappedFeature.oswElement as? OSWLineString,
           let newOSWLineString = featureCache.getOSWLineStrings().first,
           let newOSWStartingPoint = newOSWLineString.points.first
        {
            existingOSWLineString.points.append(newOSWStartingPoint)
            featureCache.addEntry(osmOldId: existingOSWLineString.id, feature: existingMappedFeature, oswElement: existingOSWLineString)
            totalFeatures += 1
            uploadOperations.append(.modify(existingOSWLineString))
        }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: inputs.workspaceId, changesetId: inputs.changesetId,
            operations: uploadOperations,
            accessToken: inputs.accessToken
        )
        guard featureCache.getOSWLineStrings().count > 0 else {
            return APIChangesetUploadResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements response
        let uploadedOSWElements = getUploadedOSWLineStrings(
            from: uploadedElements,
            featureCache: featureCache
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
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToLineStringWithStatus(
        _ feature: any AccessibilityFeatureProtocol,
        additionalTags: [String: String] = [:]
    ) -> OSWElementWithStatus? {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .linestring else {
            return nil
        }
        guard let featureLocationElement: OSMLocationElement = feature.locationDetails?.locations.first,
              featureLocationElement.isWay, !featureLocationElement.isClosed else {
            return nil
        }
        var isExisting = false
        var id = String(idGenerator.nextId())
        var version = "1"
        var oswPoints: [OSWPoint] = []
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
            oswPoints.append(point)
        }
        var additionalTags = additionalTags
        /// If feature is of type editable accessibility feature, then also add the calculated attribute values as a property to the linestring
        var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
        if let editableFeature = feature as? EditableAccessibilityFeature {
            calculatedAttributeValues = editableFeature.calculatedAttributeValues
        }
        if let editableFeature = feature as? EditableAccessibilityFeature, editableFeature.isExisting {
            guard let existingLineString = editableFeature.oswElement as? OSWLineString else {
                return nil
            }
            isExisting = true
            id = existingLineString.id
            version = existingLineString.version
            oswPoints = existingLineString.points
            additionalTags = additionalTags.merging(existingLineString.additionalTags) { current, existing in
                return current
            }
        }
        let oswLineString = OSWLineString(
            id: id,
            version: version,
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            calculatedAttributeValues: calculatedAttributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            points: oswPoints,
            additionalTags: additionalTags
        )
        return OSWElementWithStatus(oswElement: oswLineString, isExisting: isExisting)
    }
    
    private func getUploadedOSWLineStrings(
        from uploadedElements: OSMChangesetUploadResponseElements,
        featureCache: APIChangesetUploadCache
    ) -> [OSWLineString] {
        let cachedOSWLineStrings = featureCache.getOSWLineStrings()
        var uploadedOSWLineStrings: [OSWLineString?] = Array(repeating: nil, count: cachedOSWLineStrings.count)
        uploadedElements.ways.forEach { uploadedWay in
            let uploadedWayData = uploadedWay.value
            let uploadedWayOSMOldId = uploadedWayData.oldId
            guard let lineStringIndex = cachedOSWLineStrings.firstIndex(where: { $0.id == uploadedWayOSMOldId }) else {
                return
            }
            guard let matchedCachedEntry = featureCache.getEntry(osmOldId: uploadedWayOSMOldId),
                  let matchedOriginalOSWLineString = matchedCachedEntry.oswElement as? OSWLineString else {
                return
            }
            /// First, get a new feature cache for the nodes that belong to this linestring
            let pointsCache: APIChangesetUploadCache = APIChangesetUploadCache()
            matchedOriginalOSWLineString.points.forEach { point in
                pointsCache.addEntry(osmOldId: point.id, feature: nil, oswElement: point)
            }
            /// Then, map the nodes to the points
            let oswPoints: [OSWPoint] = getUploadedOSWPoints(
                from: uploadedElements,
                featureCache: pointsCache
            )
            /// Lastly, create the linestring
            let uploadedOSWLineString = OSWLineString(
                id: uploadedWayData.newId, version: uploadedWayData.newVersion,
                oswElementClass: matchedOriginalOSWLineString.oswElementClass,
                attributeValues: matchedOriginalOSWLineString.attributeValues,
                calculatedAttributeValues: matchedOriginalOSWLineString.calculatedAttributeValues,
                experimentalAttributeValues: matchedOriginalOSWLineString.experimentalAttributeValues,
                points: oswPoints,
                additionalTags: matchedOriginalOSWLineString.additionalTags
            )
            uploadedOSWLineStrings[lineStringIndex] = uploadedOSWLineString
        }
        return uploadedOSWLineStrings.compactMap { $0 }
    }
}

/**
 Extension to handle polygon transmission
 */
extension APIChangesetUploadController {
    func uploadPolygons(
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        liveMappingData: LiveMappingData,
        inputs: APIChangesetUploadInputs
    ) async throws -> APIChangesetUploadResults {
        let accessibilityFeatures = accessibilityFeatures
        let totalFeatures = accessibilityFeatures.count
        /// Map Accessibility Features to OSW Elements
        let featureCache: APIChangesetUploadCache = APIChangesetUploadCache()
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: inputs.accessibilityFeatureClass,
            captureData: inputs.captureData, liveMappingData: liveMappingData
        )
        for feature in accessibilityFeatures {
            let oswElementWithStatus = featureToPolygonWithStatus(feature, additionalTags: additionalTags)
            guard let oswElement = oswElementWithStatus?.oswElement else { continue }
            let osmOldId = oswElement.id
            featureCache.addEntry(
                osmOldId: osmOldId, feature: feature, oswElement: oswElement,
                isExisting: oswElementWithStatus?.isExisting ?? false
            )
        }
        /// Prepare upload operations from the OSW Elements, and perform upload
        let uploadOperations: [ChangesetDiffOperation] = featureCache.getOSWElementsWithStatus().map {
            return $0.isExisting ? .modify($0.oswElement) : .create($0.oswElement)
        }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: inputs.workspaceId, changesetId: inputs.changesetId,
            operations: uploadOperations,
            accessToken: inputs.accessToken
        )
        guard featureCache.getOSWPolygons().count > 0 else {
            return APIChangesetUploadResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements
        let uploadedOSWElements = getUploadedOSWPolygons(
            from: uploadedElements,
            featureCache: featureCache
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
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToPolygonWithStatus(
        _ feature: any AccessibilityFeatureProtocol,
        additionalTags: [String: String] = [:]
    ) -> OSWElementWithStatus? {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .polygon else {
            return nil
        }
        guard let featureLocationElement: OSMLocationElement = feature.locationDetails?.locations.first,
              featureLocationElement.isWay, featureLocationElement.isClosed else {
            return nil
        }
        var isExisting = false
        var id = String(idGenerator.nextId())
        var version = "1"
        var oswPoints: [OSWPoint] = []
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
            oswPoints.append(point)
        }
        var additionalTags = additionalTags
        /// If feature is of type editable accessibility feature, then also add the calculated attribute values as a property to the polygon
        var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
        if let editableFeature = feature as? EditableAccessibilityFeature {
            calculatedAttributeValues = editableFeature.calculatedAttributeValues
        }
        if let editableFeature = feature as? EditableAccessibilityFeature, editableFeature.isExisting {
            guard let existingPolygon = editableFeature.oswElement as? OSWPolygon else {
                return nil
            }
            isExisting = true
            id = existingPolygon.id
            version = existingPolygon.version
            oswPoints = existingPolygon.points
            additionalTags = additionalTags.merging(existingPolygon.additionalTags) { current, existing in
                return current
            }
        }
        let oswPolygon = OSWPolygon(
            id: id,
            version: version,
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            calculatedAttributeValues: calculatedAttributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            points: oswPoints,
            additionalTags: additionalTags
        )
        return OSWElementWithStatus(oswElement: oswPolygon, isExisting: isExisting)
    }
    
    /// Polygons are closed ways, so they work similar to linestrings in terms of mapping the uploaded elements response back to the original features.
    private func getUploadedOSWPolygons(
        from uploadedElements: OSMChangesetUploadResponseElements,
        featureCache: APIChangesetUploadCache
    ) -> [OSWPolygon] {
        let cachedOSWPolygons = featureCache.getOSWPolygons()
        var uploadedOSWPolygons: [OSWPolygon?] = Array(repeating: nil, count: cachedOSWPolygons.count)
        uploadedElements.ways.forEach { uploadedWay in
            let uploadedWayData = uploadedWay.value
            let uploadedWayOSMOldId = uploadedWayData.oldId
            guard let polygonIndex = cachedOSWPolygons.firstIndex(where: { $0.id == uploadedWayOSMOldId }) else {
                return
            }
            guard let matchedCachedEntry = featureCache.getEntry(osmOldId: uploadedWayOSMOldId),
                  let matchedOriginalOSWPolygon = matchedCachedEntry.oswElement as? OSWPolygon else {
                return
            }
            /// First, get a new feature cache for the nodes that belong to this polygon
            let pointsCache: APIChangesetUploadCache = APIChangesetUploadCache()
            matchedOriginalOSWPolygon.points.forEach { point in
                pointsCache.addEntry(osmOldId: point.id, feature: nil, oswElement: point)
            }
            /// Then, map the nodes to the points
            let oswPoints: [OSWPoint] = getUploadedOSWPoints(
                from: uploadedElements,
                featureCache: pointsCache
            )
            /// Lastly, create the polygon
            let uploadedOSWPolygon = OSWPolygon(
                id: uploadedWayData.newId, version: uploadedWayData.newVersion,
                oswElementClass: matchedOriginalOSWPolygon.oswElementClass,
                attributeValues: matchedOriginalOSWPolygon.attributeValues,
                calculatedAttributeValues: matchedOriginalOSWPolygon.calculatedAttributeValues,
                experimentalAttributeValues: matchedOriginalOSWPolygon.experimentalAttributeValues,
                points: oswPoints,
                additionalTags: matchedOriginalOSWPolygon.additionalTags
            )
            uploadedOSWPolygons[polygonIndex] = uploadedOSWPolygon
        }
        return uploadedOSWPolygons.compactMap { $0 }
    }
}
