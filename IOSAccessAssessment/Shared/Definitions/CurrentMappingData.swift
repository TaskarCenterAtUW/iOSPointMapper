//
//  CurrentMappingData.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/9/25.
//

import Foundation

enum CurrentMappingDataError: Error, LocalizedError {
}

class CurrentMappingData {
    var featuresMap: [AccessibilityFeatureClass: [OSWElement]] = [:]
    var otherFeatures: [OSWElement] = []
    
    init() {
        
    }
    
    init(osmMapDataResponse: OSMMapDataResponse, accessibilityFeatureClasses: [AccessibilityFeatureClass]) {
        updateFeatures(with: osmMapDataResponse, accessibilityFeatureClasses: accessibilityFeatureClasses)
    }
    
    func updateFeatures(with osmMapDataResponse: OSMMapDataResponse, accessibilityFeatureClasses: [AccessibilityFeatureClass]) {
        for featureClass in accessibilityFeatureClasses {
            let oswElementClass = featureClass.oswPolicy.oswElementClass
        }
    }
}
