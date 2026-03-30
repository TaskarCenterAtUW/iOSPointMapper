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

class CurrentMappingData {
    var featuresMap: [AccessibilityFeatureClass: [any OSWElement]] = [:]
//    var otherFeatures: [OSWElement] = []
    
    init() {
        
    }
    
    init(osmMapDataResponse: OSMMapDataResponse, accessibilityFeatureClasses: [AccessibilityFeatureClass]) {
        self.featuresMap = getFeatures(with: osmMapDataResponse, accessibilityFeatureClasses: accessibilityFeatureClasses)
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
                let matchingOSWLineStrings: [OSWLineString] = featureWays.values.filter { way in
                    return identifyingFieldTags.allSatisfy { tagKey, tagValue in
                        return way.tags[tagKey] == tagValue
                    }
                }.compactMap { way in
                    return OSWLineString(
                        osmWay: way, oswElementClass: oswElementClass,
                        osmNodes: Array(featureNodes.values)
                    )
                }
                featuresMap[featureClass]?.append(contentsOf: matchingOSWLineStrings)
            case .relation:
                let matchingOSWPolygons: [OSWPolygon] = featureRelations.values.filter { relation in
                    return identifyingFieldTags.allSatisfy { tagKey, tagValue in
                        return relation.tags[tagKey] == tagValue
                    }
                }.compactMap { relation in
                    return OSWPolygon(
                        osmRelation: relation, oswElementClass: oswElementClass,
                        osmMemberElements: osmElements
                    )
                }
                featuresMap[featureClass]?.append(contentsOf: matchingOSWPolygons)
            }
        }
        return featuresMap
    }
    
    func getNearestFeature(
        to location: CLLocationCoordinate2D, featureClass: AccessibilityFeatureClass,
        distanceThreshold: CLLocationDistance = 50.0
    ) -> (any OSWElement)? {
        return nil
    }
}
