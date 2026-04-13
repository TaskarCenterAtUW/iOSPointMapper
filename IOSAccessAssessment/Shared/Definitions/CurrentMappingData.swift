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

class CurrentMappingData: CustomStringConvertible {
    
    var featuresMap: [AccessibilityFeatureClass: [any OSWElement]] = [:]
//    var otherFeatures: [OSWElement] = []
    
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
        self.featuresMap = getFeatures(with: osmMapDataResponse, accessibilityFeatureClasses: accessibilityFeatureClasses)
        print("Initialized features map with OSM data. \n\(description)")
    }
    
    /// Note: Replaces the feature map instead of incrementally updating it.
    func update(osmMapDataResponse: OSMMapDataResponse, accessibilityFeatureClasses: [AccessibilityFeatureClass]) {
        self.featuresMap = getFeatures(with: osmMapDataResponse, accessibilityFeatureClasses: accessibilityFeatureClasses)
        print("Updated features map with new OSM data. \n\(description)")
    }
    
    func getFeatures(
        with osmMapDataResponse: OSMMapDataResponse, accessibilityFeatureClasses: [AccessibilityFeatureClass]
    ) -> [AccessibilityFeatureClass: [any OSWElement]] {
        var featuresMap: [AccessibilityFeatureClass: [any OSWElement]] = [:]
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
            if featuresMap[featureClass] == nil {
                featuresMap[featureClass] = []
            }
            let oswElementClass = featureClass.oswPolicy.oswElementClass
            let geometry = oswElementClass.geometry
            let identifyingFieldTags: [String: String] = oswElementClass.identifyingFieldTags
            
            switch geometry.osmElementType {
            case .node:
                let matchingOSWPoints: [OSWPoint] = featureNodes.values.filter { node in
                    return identifyingFieldTags.allSatisfy { tagKey, tagValue in
                        return node.tags[tagKey] == tagValue
                    }
                }.compactMap { node in
                    return OSWPoint(osmNode: node, oswElementClass: oswElementClass)
                }
                featuresMap[featureClass]?.append(contentsOf: matchingOSWPoints)
            case .way:
                var filteredFeatureWays: [OSMWay] = featureWays.values.filter { way in
                    return identifyingFieldTags.allSatisfy { tagKey, tagValue in
                        return way.tags[tagKey] == tagValue
                    }
                }
                if geometry == .polygon {
                    /// For polygon features, we only want to consider closed ways (where the first and last node references are the same)
                    filteredFeatureWays = filteredFeatureWays.filter { way in
                        return way.nodeRefs.first == way.nodeRefs.last
                    }
                    let matchingOSWPolygons: [OSWPolygon] = filteredFeatureWays.compactMap { way in
                        return OSWPolygon(
                            osmWay: way, oswElementClass: oswElementClass,
                            osmNodes: Array(featureNodes.values)
                        )
                    }
                    featuresMap[featureClass]?.append(contentsOf: matchingOSWPolygons)
                } else {
                    let matchingOSWLineStrings: [OSWLineString] = filteredFeatureWays.compactMap { way in
                        return OSWLineString(
                            osmWay: way, oswElementClass: oswElementClass,
                            osmNodes: Array(featureNodes.values)
                        )
                    }
                    featuresMap[featureClass]?.append(contentsOf: matchingOSWLineStrings)
                }
            case .relation:
                let matchingOSWPolygons: [OSWMultiPolygon] = featureRelations.values.filter { relation in
                    return identifyingFieldTags.allSatisfy { tagKey, tagValue in
                        return relation.tags[tagKey] == tagValue
                    }
                }.compactMap { relation in
                    return OSWMultiPolygon(
                        osmRelation: relation, oswElementClass: oswElementClass,
                        osmMemberElements: osmElements
                    )
                }
                featuresMap[featureClass]?.append(contentsOf: matchingOSWPolygons)
            }
        }
        return featuresMap
    }
    
    /**
     This function takes in OSM location details and an accessibility feature class, and returns the nearest feature of that class within a specified distance threshold.
     It iterates through the features of the specified class, calculates the distance from each feature to the given OSM location details, and keeps track of the nearest feature found that is within the distance threshold. If no features are found within the threshold, it returns nil.
     */
    func getNearestFeature(
        to osmLocationDetails: OSMLocationDetails, featureClass: AccessibilityFeatureClass,
        distanceThreshold: CLLocationDistance = 50.0
    ) -> (any OSWElement)? {
        guard let features = featuresMap[featureClass] else { return nil }
        var nearestFeature: (any OSWElement)?
        var nearestDistance: CLLocationDistance = distanceThreshold
        
        for feature in features {
            guard let featureOSMLocationDetails = feature.getOSMLocationDetails() else { continue }
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
        guard let features = featuresMap[featureClass] else { return nil }
        var nearestFeature: (any OSWElement)?
        let captureIdString = captureId.uuidString
        
        for feature in features {
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
}
