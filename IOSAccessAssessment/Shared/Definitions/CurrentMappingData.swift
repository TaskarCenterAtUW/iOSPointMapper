//
//  CurrentMappingData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation
import CoreLocation

enum CurrentMappingDataError: Error, LocalizedError {
}

/**
    This class serves as a centralized data structure to store and manage the current mapping data for accessibility features.
    It maintains mappings of OSW elements (points, line strings, polygons) by their IDs for efficient access, as well as a mapping of accessibility feature classes to their corresponding feature IDs. This allows for quick retrieval and updates of features based on their unique identifiers and classes.
 */
class CurrentMappingData: CustomStringConvertible {
    /// OSW elements mapped by their IDs for quick access. This allows for efficient retrieval and updates of features based on their unique identifiers.
    var points: [String: OSWPoint] = [:]
    var lineStrings: [String: OSWLineString] = [:]
    var polygons: [String: OSWPolygon] = [:]
//    var multiPolygons: [String: OSWMultiPolygon] = []
    
    /// Mapping from accessibility feature class to the list of feature IDs for that class. This is used to quickly check if a feature with a given ID already exists in the map data for a specific class, which can help avoid duplicates and facilitate updates.
    var featuresMap: [AccessibilityFeatureClass: [String]] = [:]
    
    init() {
        
    }
    
    var description: String {
        var description = "CurrentMappingData:\n"
        for (featureClass, features) in featuresMap {
            description += "- \(featureClass.name): \(features.count) features\n"
        }
        return description
    }
    
    init(osmMapDataResponse: OSMMapDataResponse, accessibilityFeatureClasses: [AccessibilityFeatureClass]) {
        self.rebuildFeaturesFromResponse(with: osmMapDataResponse, accessibilityFeatureClasses: accessibilityFeatureClasses)
        print("Initialized features map with OSM data. \n\(description)")
    }
    
    func replace(osmMapDataResponse: OSMMapDataResponse, accessibilityFeatureClasses: [AccessibilityFeatureClass]) {
        self.rebuildFeaturesFromResponse(with: osmMapDataResponse, accessibilityFeatureClasses: accessibilityFeatureClasses)
        print("Updated features map with new OSM data. \n\(description)")
    }
    
    /**
     Updates the features map for a specific accessibility feature class by adding or replacing the features of that class with the provided elements. This function can be used to incrementally update the features map when new data is available for a specific feature class, without needing to rebuild the entire map from scratch.
     */
    func updateFeatures(_ elements: [any OSWElement], for featureClass: AccessibilityFeatureClass) {
        var existingFeatures = featuresMap[featureClass, default: []]
        elements.forEach { element in
            if let existingIndex = featureIdToIndex[element.id] {
                // Update the existing feature
                existingFeatures[existingIndex] = element
            } else {
                // Add the new feature
                existingFeatures.append(element)
            }
        }
        featuresMap[featureClass] = existingFeatures
    }
    
    func rebuildFeaturesFromResponse(
        with osmMapDataResponse: OSMMapDataResponse, accessibilityFeatureClasses: [AccessibilityFeatureClass]
    ) {
        var points: [String: OSWPoint] = [:]
        var lineStrings: [String: OSWLineString] = [:]
        var polygons: [String: OSWPolygon] = [:]
        var featuresMap: [AccessibilityFeatureClass: [String]] = [:]
        
        let osmMapDataResponseElements: [OSMMapDataResponseElement] = osmMapDataResponse.elements
        let osmElements: [any OSMElement] = osmMapDataResponseElements.compactMap { element in
            return element.toOSMElement()
        }
        var featureNodes: [String: OSMNode] = [:]
        var featureWays: [String: OSMWay] = [:]
        var featureRelations: [String: OSMRelation] = [:]
        osmElements.forEach { osmElement in
            if let osmNode = osmElement as? OSMNode {
                featureNodes[osmElement.id] = osmNode
            } else if let osmWay = osmElement as? OSMWay {
                featureWays[osmElement.id] = osmWay
            } else if let osmRelation = osmElement as? OSMRelation {
                featureRelations[osmElement.id] = osmRelation
            }
        }
        
        for featureClass in accessibilityFeatureClasses {
            let oswElementClass = featureClass.oswPolicy.oswElementClass
            let geometry = oswElementClass.geometry
            let identifyingFieldTags: [String: String] = oswElementClass.identifyingFieldTags
            
            switch geometry {
            case .point:
                var matchingOSWPoints: [String: OSWPoint] = [:]
                featureNodes.values.forEach { node in
                    guard identifyingFieldTags.allSatisfy({ tagKey, tagValue in
                        return node.tags[tagKey] == tagValue
                    }) else { return }
                    let oswPoint = OSWPoint(osmNode: node, oswElementClass: oswElementClass)
                    matchingOSWPoints[oswPoint.id] = oswPoint
                }
                points.merge(matchingOSWPoints) { (_, new) in new }
                featuresMap[featureClass] = Array(matchingOSWPoints.keys)
            case .linestring:
                var matchingOSWLineStrings: [String: OSWLineString] = [:]
                var matchingOSWChildPoints: [String: OSWPoint] = [:]
                featureWays.values.forEach { way in
                    guard identifyingFieldTags.allSatisfy({ tagKey, tagValue in
                        return way.tags[tagKey] == tagValue
                    }) else { return }
                    let oswLineString = OSWLineString(osmWay: way, oswElementClass: oswElementClass)
                    matchingOSWLineStrings[oswLineString.id] = oswLineString
                    /// Add node refs as new points if they don't already exist in the points map
                    way.nodeRefs.forEach { nodeRef in
                        guard let osmNode = featureNodes[nodeRef] else { return }
                        guard matchingOSWChildPoints[nodeRef] == nil && points[nodeRef] == nil else { return }
                        let oswPoint = OSWPoint(osmNode: osmNode, oswElementClass: oswElementClass)
                        matchingOSWChildPoints[nodeRef] = oswPoint
                    }
                }
                lineStrings.merge(matchingOSWLineStrings) { (_, new) in new }
                points.merge(matchingOSWChildPoints) { (_, new) in new }
                featuresMap[featureClass] = Array(matchingOSWLineStrings.keys)
            case .polygon:
                var matchingOSWPolygons: [String: OSWPolygon] = [:]
                var matchingOSWChildPoints: [String: OSWPoint] = [:]
                featureWays.values.forEach { way in
                    guard identifyingFieldTags.allSatisfy({ tagKey, tagValue in
                        return way.tags[tagKey] == tagValue
                    }) else { return }
                    let oswPolygon = OSWPolygon(osmWay: way, oswElementClass: oswElementClass)
                    matchingOSWPolygons[oswPolygon.id] = oswPolygon
                    /// Add node refs as new points if they don't already exist in the points map
                    way.nodeRefs.forEach { nodeRef in
                        guard let osmNode = featureNodes[nodeRef] else { return }
                        guard matchingOSWChildPoints[nodeRef] == nil && points[nodeRef] == nil else { return }
                        let oswPoint = OSWPoint(osmNode: osmNode, oswElementClass: oswElementClass)
                        matchingOSWChildPoints[nodeRef] = oswPoint
                    }
                }
                polygons.merge(matchingOSWPolygons) { (_, new) in new }
                points.merge(matchingOSWChildPoints) { (_, new) in new }
                featuresMap[featureClass] = Array(matchingOSWPolygons.keys)
            }
        }
        self.points = points
        self.lineStrings = lineStrings
        self.polygons = polygons
        self.featuresMap = featuresMap
    }
    
    /**
     This function takes in OSM location details and an accessibility feature class, and returns the nearest feature of that class within a specified distance threshold.
     It iterates through the features of the specified class, calculates the distance from each feature to the given OSM location details, and keeps track of the nearest feature found that is within the distance threshold. If no features are found within the threshold, it returns nil.
     */
    func getNearestFeature(
        to osmLocationDetails: OSMLocationDetails, featureClass: AccessibilityFeatureClass,
        distanceThreshold: CLLocationDistance = 50.0
    ) -> (any OSWElement)? {
        guard let featureIds = featuresMap[featureClass] else { return nil }
        var nearestFeature: (any OSWElement)?
        var nearestDistance: CLLocationDistance = distanceThreshold
        let geometry = featureClass.oswPolicy.oswElementClass.geometry
        
        for featureId in featureIds {
            guard let feature = getFeature(featureId: featureId, geometry: geometry) else { continue }
            guard let featureOSMLocationDetails = self.getFeatureOSMLocationDetails(
                feature: feature, geometry: geometry
            ) else { continue }
            guard let distance = LocationHelpers.distanceBetweenSimilarOSMLocationDetails(
                srcLocationDetails: featureOSMLocationDetails, dstLocationDetails: osmLocationDetails
            ) else { continue }
            if distance < nearestDistance {
                nearestFeature = feature
                nearestDistance = distance
            }
        }
        return nearestFeature
    }
    
    /**
     This function takes in OSM location details, an accessibility feature class, and a capture ID, and returns the feature of that class whose capture ID matches the given capture ID.
     */
    func getCaptureMatchedFeature(
        to osmLocationDetails: OSMLocationDetails, featureClass: AccessibilityFeatureClass,
        captureId: UUID
    ) -> (any OSWElement)? {
        guard let featureIds = featuresMap[featureClass] else { return nil }
        var nearestFeature: (any OSWElement)?
        let geometry = featureClass.oswPolicy.oswElementClass.geometry
        let captureIdString = captureId.uuidString
        
        for featureId in featureIds {
            guard let feature = getFeature(featureId: featureId, geometry: geometry) else { continue }
            guard let featureCaptureId = feature.getCaptureId() else { continue }
            if featureCaptureId == captureIdString {
                nearestFeature = feature
                break
            }
        }
        return nearestFeature
    }
    
    /**
     This function matches features based on both proximity and capture ID.
     It first attempts to find a feature that matches the capture ID, and if it finds one, it directly returns it. Else,  it falls back to finding the nearest feature within the distance threshold.
     */
    func getMatchedFeature(
        to osmLocationDetails: OSMLocationDetails, featureClass: AccessibilityFeatureClass,
        captureId: UUID?,
        distanceThreshold: CLLocationDistance = 50.0
    ) -> (any OSWElement)? {
        if let captureId = captureId {
            let captureMatchedFeature = getCaptureMatchedFeature(
                to: osmLocationDetails, featureClass: featureClass, captureId: captureId
            )
            if let captureMatchedFeature = captureMatchedFeature {
                return captureMatchedFeature
            }
        }
        return getNearestFeature(
            to: osmLocationDetails, featureClass: featureClass, distanceThreshold: distanceThreshold
        )
    }
    
    private func getFeature(
        featureId: String, geometry: OSWGeometry
    ) -> (any OSWElement)? {
        switch geometry {
        case .point:
            return points[featureId]
        case .linestring:
            return lineStrings[featureId]
        case .polygon:
            return polygons[featureId]
        }
    }
    
    private func getFeature(featureId: String) -> (any OSWElement)? {
        if let point = points[featureId] {
            return point
        } else if let lineString = lineStrings[featureId] {
            return lineString
        } else if let polygon = polygons[featureId] {
            return polygon
        }
        return nil
    }
    
    /// Note: OSWGeometry is not required as a parameter here since the feature itself carries geometry information based on the type of OSWElement it is.
    private func getFeatureOSMLocationDetails(
        feature: any OSWElement, geometry: OSWGeometry
    ) -> OSMLocationDetails? {
        switch geometry {
        case .point:
            guard let point = feature as? OSWPoint else { return nil }
            let coordinates: [CLLocationCoordinate2D] = [CLLocationCoordinate2D(
                latitude: point.latitude, longitude: point.longitude
            )]
            let osmLocationElement: OSMLocationElement = OSMLocationElement(
                coordinates: coordinates, isWay: false, isClosed: false
            )
            return OSMLocationDetails(locations: [osmLocationElement])
        case .linestring:
            guard let lineString = feature as? OSWLineString else { return nil }
            let coordinates: [CLLocationCoordinate2D] = lineString.pointRefs.compactMap { pointRef in
                guard let point = self.getFeature(featureId: pointRef, geometry: .point) as? OSWPoint else { return nil }
                return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            }
            let osmLocationElement: OSMLocationElement = OSMLocationElement(
                coordinates: coordinates, isWay: true, isClosed: false
            )
            return OSMLocationDetails(locations: [osmLocationElement])
        case .polygon:
            guard let polygon = feature as? OSWPolygon else { return nil }
            let coordinates: [CLLocationCoordinate2D] = polygon.pointRefs.compactMap { pointRef in
                guard let point = self.getFeature(featureId: pointRef, geometry: .point) as? OSWPoint else { return nil }
                return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
            }
            let osmLocationElement: OSMLocationElement = OSMLocationElement(
                coordinates: coordinates, isWay: true, isClosed: true
            )
            return OSMLocationDetails(locations: [osmLocationElement])
        }
    }
}
