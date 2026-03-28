//
//  APITransmissionController.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI
import CoreLocation

enum APITransmissionError: Error, LocalizedError {
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

class APITransmissionController: ObservableObject {
    private var idGenerator: IntIdGenerator = IntIdGenerator()
    public var capturedFrameIds: Set<UUID> = []
    
    func uploadFeatures(
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        inputs: APITransmissionInputs
    ) async throws -> APITransmissionResults {
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
        var apiTransmissionResults: APITransmissionResults
        switch inputs.accessibilityFeatureClass.oswPolicy.oswElementClass.geometry {
        case .point:
            apiTransmissionResults = try await uploadPoints(
                accessibilityFeatures: accessibilityFeatures,
                mappingData: mappingData,
                inputs: inputs
            )
        case .linestring:
            apiTransmissionResults = try await uploadLineStrings(
                accessibilityFeatures: accessibilityFeatures,
                mappingData: mappingData,
                inputs: inputs
            )
        case .polygon:
            apiTransmissionResults = try await uploadPolygons(
                accessibilityFeatures: accessibilityFeatures,
                mappingData: mappingData,
                inputs: inputs
            )
        }
        return APITransmissionResults(
            from: apiTransmissionResults,
            isFailedCaptureUpload: isFailedCaptureUpload
        )
    }
    
    func uploadCapturePoint(inputs: APITransmissionInputs) async throws {
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
        mappingData: MappingData,
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
extension APITransmissionController {
    func uploadPoints(
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        inputs: APITransmissionInputs
    ) async throws -> APITransmissionResults {
        let accessibilityFeatures = accessibilityFeatures
        let totalFeatures = accessibilityFeatures.count
        /// Map Accessibility Features to OSW Elements
        let featureCache: APIFeatureCache = APIFeatureCache()
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: inputs.accessibilityFeatureClass,
            captureData: inputs.captureData, mappingData: mappingData
        )
        for feature in accessibilityFeatures {
            let oswElement = featureToPoint(feature, additionalTags: additionalTags)
            guard let oswElement else { continue }
            let osmOldId = oswElement.id
            featureCache.addEntry(osmOldId: osmOldId, feature: feature, oswElement: oswElement)
        }
        /// Prepare upload operations from the OSW Elements, and perform upload
        let uploadOperations: [ChangesetDiffOperation] = featureCache.getOSWElements().map { .create($0) }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: inputs.workspaceId, changesetId: inputs.changesetId,
            operations: uploadOperations,
            accessToken: inputs.accessToken
        )
        guard featureCache.getOSWPoints().count > 0 else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements response
        let uploadedOSWElements = getUploadedOSWPoints(from: uploadedElements, featureCache: featureCache)
        guard !uploadedOSWElements.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
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
        return APITransmissionResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToPoint(
        _ feature: any AccessibilityFeatureProtocol,
        additionalTags: [String: String] = [:]
    ) -> OSWPoint? {
        guard let featureLocation = feature.getLastLocationCoordinate() else {
            return nil
        }
        /// If feature is of type editable accessibility feature, then also add the calculated attribute values as a property
        var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
        if let editableFeature = feature as? EditableAccessibilityFeature {
            calculatedAttributeValues = editableFeature.calculatedAttributeValues
        }
        /// Add location as additional tags as well
        var additionalTags = additionalTags
        additionalTags[APIConstants.TagKeys.calculatedLatitudeKey] = String(featureLocation.latitude)
        additionalTags[APIConstants.TagKeys.calculatedLongitudeKey] = String(featureLocation.longitude)
        let oswPoint = OSWPoint(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: feature.accessibilityFeatureClass.oswPolicy.oswElementClass,
            latitude: featureLocation.latitude,
            longitude: featureLocation.longitude,
            attributeValues: feature.attributeValues,
            calculatedAttributeValues: calculatedAttributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            additionalTags: additionalTags
        )
        return oswPoint
    }
    
    private func getUploadedOSWPoints(
        from uploadedElements: UploadedOSMResponseElements,
        featureCache: APIFeatureCache
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
extension APITransmissionController {
    func uploadLineStrings(
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        inputs: APITransmissionInputs
    ) async throws -> APITransmissionResults {
        var accessibilityFeatures = accessibilityFeatures
        var totalFeatures = accessibilityFeatures.count
        guard totalFeatures > 0, let firstFeature = accessibilityFeatures.first else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// For the sidewalk feature class, only upload one linestring representing the entire sidewalk
        if inputs.accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk {
            accessibilityFeatures = [firstFeature]
            totalFeatures = 1
        }
        /// Map Accessibility Features to OSW Elements
        let featureCache: APIFeatureCache = APIFeatureCache()
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: inputs.accessibilityFeatureClass,
            captureData: inputs.captureData, mappingData: mappingData
        )
        for feature in accessibilityFeatures {
            let oswElement = featureToLineString(feature, additionalTags: additionalTags)
            guard let oswElement else { continue }
            let osmOldId = oswElement.id
            featureCache.addEntry(osmOldId: osmOldId, feature: feature, oswElement: oswElement)
        }
        /// Prepare upload operations from the OSW Elements, and perform upload
        var uploadOperations: [ChangesetDiffOperation] = featureCache.getOSWElements().map { .create($0) }
        /// For the sidewalk class, get the previously uploaded linestring, connect it to the new linestring, and add a modify operation
        if inputs.accessibilityFeatureClass.oswPolicy.oswElementClass == .Sidewalk,
           let existingMappedFeature = mappingData.featuresMap[inputs.accessibilityFeatureClass]?.last {
            let existingOSWElement = existingMappedFeature.oswElement
            if var existingOSWLineString = existingOSWElement as? OSWLineString,
               let newOSWLineString = featureCache.getOSWLineStrings().first,
               let newOSWStartingPoint = newOSWLineString.points.first {
                existingOSWLineString.points.append(newOSWStartingPoint)
                featureCache.addEntry(osmOldId: existingOSWLineString.id, feature: existingMappedFeature, oswElement: existingOSWLineString)
                totalFeatures += 1
                uploadOperations.append(.modify(existingOSWLineString))
            }
        }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: inputs.workspaceId, changesetId: inputs.changesetId,
            operations: uploadOperations,
            accessToken: inputs.accessToken
        )
        guard featureCache.getOSWLineStrings().count > 0 else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements response
        let uploadedOSWElements = getUploadedOSWLineStrings(
            from: uploadedElements,
            featureCache: featureCache
        )
        guard !uploadedOSWElements.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
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
        return APITransmissionResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToLineString(
        _ feature: any AccessibilityFeatureProtocol,
        additionalTags: [String: String] = [:]
    ) -> OSWLineString? {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .linestring else {
            return nil
        }
        var oswPoints: [OSWPoint] = []
        guard let featureLocationElement: OSMLocationElement = feature.locationDetails?.locations.first,
              featureLocationElement.isWay else {
            return nil
        }
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
        if featureLocationElement.isClosed {
            /// If the linestring is closed, add the first point at the end to ensure it's represented as a closed linestring in OSM
            if let firstOSWPoint = oswPoints.first {
                oswPoints.append(firstOSWPoint)
            }
        }
        /// If feature is of type editable accessibility feature, then also add the calculated attribute values as a property to the linestring
        var calculatedAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] = [:]
        if let editableFeature = feature as? EditableAccessibilityFeature {
            calculatedAttributeValues = editableFeature.calculatedAttributeValues
        }
        let oswLineString = OSWLineString(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            calculatedAttributeValues: calculatedAttributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            points: oswPoints,
            additionalTags: additionalTags
        )
        return oswLineString
    }
    
    private func getUploadedOSWLineStrings(
        from uploadedElements: UploadedOSMResponseElements,
        featureCache: APIFeatureCache
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
            let pointsCache: APIFeatureCache = APIFeatureCache()
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
extension APITransmissionController {
    func uploadPolygons(
        accessibilityFeatures: [any AccessibilityFeatureProtocol],
        mappingData: MappingData,
        inputs: APITransmissionInputs
    ) async throws -> APITransmissionResults {
        let accessibilityFeatures = accessibilityFeatures
        let totalFeatures = accessibilityFeatures.count
        /// Map Accessibility Features to OSW Elements
        let featureCache: APIFeatureCache = APIFeatureCache()
        let additionalTags: [String: String] = getAdditionalTags(
            accessibilityFeatureClass: inputs.accessibilityFeatureClass,
            captureData: inputs.captureData, mappingData: mappingData
        )
        for feature in accessibilityFeatures {
            let oswElement = featureToPolygon(feature, additonalTags: additionalTags)
            guard let oswElement else { continue }
            let osmOldId = oswElement.id
            featureCache.addEntry(osmOldId: osmOldId, feature: feature, oswElement: oswElement)
        }
        /// Prepare upload operations from the OSW Elements, and perform upload
        let uploadOperations: [ChangesetDiffOperation] = featureCache.getOSWElements().map { .create($0) }
        let uploadedElements = try await ChangesetService.shared.performUploadAsync(
            workspaceId: inputs.workspaceId, changesetId: inputs.changesetId,
            operations: uploadOperations,
            accessToken: inputs.accessToken
        )
        guard featureCache.getOSWPolygons().count > 0 else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
        }
        /// Get the new ids and other details for the OSW Elements, from the uploaded elements response
        let uploadedOSWElements = getUploadedPolygons(
            from: uploadedElements,
            featureCache: featureCache
        )
        guard !uploadedOSWElements.isEmpty else {
            return APITransmissionResults(failedFeatureUploads: totalFeatures, totalFeatureUploads: totalFeatures)
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
        return APITransmissionResults(
            accessibilityFeatures: mappedAccessibilityFeatures,
            failedFeatureUploads: failedUploads, totalFeatureUploads: totalFeatures
        )
    }
    
    private func featureToPolygon(
        _ feature: any AccessibilityFeatureProtocol,
        additonalTags: [String: String] = [:]
    ) -> OSWPolygon? {
        let oswElementClass = feature.accessibilityFeatureClass.oswPolicy.oswElementClass
        guard oswElementClass.geometry == .polygon else {
            return nil
        }
        
        var oswElements: [any OSWElement] = []
//        guard let featureLocationArrays: [[CLLocationCoordinate2D]] = feature.locationDetails?.coordinates,
//              let firstLocationArray = featureLocationArrays.first, !firstLocationArray.isEmpty else {
//            return nil
//        }
        guard let featureLocationDetails: OSMLocationDetails = feature.locationDetails,
              !featureLocationDetails.locations.isEmpty else {
            return nil
        }
        featureLocationDetails.locations.forEach { locationElement in
//        featureLocationArrays.forEach { locationArray in
            guard !locationElement.coordinates.isEmpty else { return }
            var oswPoints: [OSWPoint] = []
            locationElement.coordinates.forEach { location in
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
            if !locationElement.isWay && locationElement.coordinates.count <= 2 {
                oswElements.append(contentsOf: oswPoints)
            } else {
                if locationElement.isClosed {
                    /// If the linestring is closed, add the first point at the end to ensure it's represented as a closed linestring in OSM
                    if let firstOSWPoint = oswPoints.first {
                        oswPoints.append(firstOSWPoint)
                    }
                }
                let oswLineString = OSWLineString(
                    id: String(idGenerator.nextId()),
                    version: "1",
                    oswElementClass: oswElementClass,
                    attributeValues: [:],
                    calculatedAttributeValues: [:],
                    experimentalAttributeValues: [:],
                    points: oswPoints
                )
                oswElements.append(oswLineString)
            }
        }
        let oswMembers = oswElements.map {
            /// TODO: Add the exact role of the member
            return OSWRelationMember(element: $0)
        }
        let oswPolygon = OSWPolygon(
            id: String(idGenerator.nextId()),
            version: "1",
            oswElementClass: oswElementClass,
            attributeValues: feature.attributeValues,
            experimentalAttributeValues: feature.experimentalAttributeValues,
            members: oswMembers,
            additionalTags: additonalTags,
        )
        return oswPolygon
    }
    
    private func getUploadedPolygons(
        from uploadedElements: UploadedOSMResponseElements,
        featureCache: APIFeatureCache
    ) -> [OSWPolygon] {
        let cachedOSWPolygons = featureCache.getOSWPolygons()
        var uploadedOSWPolygons: [OSWPolygon?] = Array(repeating: nil, count: cachedOSWPolygons.count)
        uploadedElements.relations.forEach { relation in
            let uploadedRelationData = relation.value
            let uploadedRelationOSMOldId = uploadedRelationData.oldId
            guard let polygonIndex = cachedOSWPolygons.firstIndex(where: { $0.id == uploadedRelationOSMOldId }) else {
                return
            }
            guard let matchedCachedEntry = featureCache.getEntry(osmOldId: uploadedRelationOSMOldId),
                  let matchedOriginalOSWPolygon = matchedCachedEntry.oswElement as? OSWPolygon else {
                return
            }
            /// First, create a new feature cache for the point members of the polygon
            let pointsCache: APIFeatureCache = APIFeatureCache()
            matchedOriginalOSWPolygon.members.forEach { member in
                let element = member.element
                guard let point = element as? OSWPoint else { return }
                pointsCache.addEntry(osmOldId: point.id, feature: nil, oswElement: point)
            }
            /// Then, get the uploaded points from the uploaded elements response
            let oswPoints: [OSWPoint] = getUploadedOSWPoints(
                from: uploadedElements,
                featureCache: pointsCache
            )
            /// Second, create a new feature cache for the linestring members of the polygon
            let lineStringsCache: APIFeatureCache = APIFeatureCache()
            matchedOriginalOSWPolygon.members.forEach { member in
                let element = member.element
                guard let lineString = element as? OSWLineString else { return }
                lineStringsCache.addEntry(osmOldId: lineString.id, feature: nil, oswElement: lineString)
            }
            /// Then, get the uploaded linestrings from the uploaded elements response
            let oswLineStrings: [OSWLineString] = getUploadedOSWLineStrings(
                from: uploadedElements,
                featureCache: lineStringsCache
            )
            /// Lastly, create the polygon
            let oswElements: [any OSWElement] = oswPoints + oswLineStrings
            let oswMembers: [OSWRelationMember] = oswElements.map {
                OSWRelationMember(element: $0)
            }
            let uploadedOSWPolygon = OSWPolygon(
                id: uploadedRelationData.newId, version: uploadedRelationData.newVersion,
                oswElementClass: matchedOriginalOSWPolygon.oswElementClass,
                attributeValues: matchedOriginalOSWPolygon.attributeValues,
                experimentalAttributeValues: matchedOriginalOSWPolygon.experimentalAttributeValues,
                members: oswMembers,
                additionalTags: matchedOriginalOSWPolygon.additionalTags,
            )
            uploadedOSWPolygons[polygonIndex] = uploadedOSWPolygon
        }
        return uploadedOSWPolygons.compactMap { $0 }
    }
}
