//
//  AppBasedExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/26.
//
import PointNMapShared
import CoreLocation
import MapKit

enum LocationType: String, Codable {
    case captureLocation = "capture_location"
    case correctedLocation = "corrected_location"
}

extension AttributeEstimationPipeline {
    func processIsExistingRequest(
        deviceLocation: CLLocationCoordinate2D,
        mappingData: CurrentMappingData,
        accessibilityFeature: MappedEditableAccessibilityFeature,
        locationType: LocationType = .captureLocation,
        featureIndex: Int? = nil
    ) {
        /// Threshold needs to be in Map Units
        let distanceThreshold = PointNMapConstants.WorkspaceConstants.fetchUpdateRadiusThresholdInMeters * MKMapPointsPerMeterAtLatitude(deviceLocation.latitude)
        guard let locationDetails = locationType == .captureLocation ? accessibilityFeature.locationDetails : accessibilityFeature.correctedLocationDetails else {
//            accessibilityFeature.setIsExisting(false)
            locationType == .captureLocation ? accessibilityFeature.setIsExisting(false) : accessibilityFeature.setCorrectedIsExisting(false)
            return
        }
        let matchedElement: (any OSWElement)? = mappingData.getMatchedFeature(
            to: locationDetails, featureClass: accessibilityFeature.accessibilityFeatureClass,
            captureId: self.captureImageData?.id,
            distanceThreshold: distanceThreshold,
//            featureIndex: featureIndex
        )
        guard let matchedElement = matchedElement else {
//            accessibilityFeature.setIsExisting(false)
            locationType == .captureLocation ? accessibilityFeature.setIsExisting(false) : accessibilityFeature.setCorrectedIsExisting(false)
            return
        }
        let isExisting = accessibilityFeature.accessibilityFeatureClass.kind.oswPolicy.isExistingFirst
//        accessibilityFeature.setIsExisting(isExisting)
//        accessibilityFeature.setOSWElement(oswElement: matchedElement)
        locationType == .captureLocation ? accessibilityFeature.setIsExisting(isExisting) : accessibilityFeature.setCorrectedIsExisting(isExisting)
        locationType == .captureLocation ? accessibilityFeature.setOSWElement(oswElement: matchedElement) : accessibilityFeature.setCorrectedOSWElement(matchedElement)
    }
    
    func processNearestFeaturesRequest(
        deviceLocation: CLLocationCoordinate2D,
        mappingData: CurrentMappingData,
        accessibilityFeature: MappedEditableAccessibilityFeature,
        locationType: LocationType = .captureLocation,
        featureIndex: Int? = nil
    ) {
        /// Threshold needs to be in Map Units
        let distanceThreshold = PointNMapConstants.WorkspaceConstants.fetchUpdateRadiusThresholdInMeters * MKMapPointsPerMeterAtLatitude(deviceLocation.latitude)
        guard let locationDetails = locationType == .captureLocation ? accessibilityFeature.locationDetails : accessibilityFeature.correctedLocationDetails else {
            return
        }
        let nearestOSWElements: [(any OSWElement, CLLocationDistance)] = mappingData.getNearestFeatures(
            to: locationDetails, featureClass: accessibilityFeature.accessibilityFeatureClass,
            captureId: self.captureImageData?.id,
            distanceThreshold: distanceThreshold,
//            featureIndex: featureIndex
        )
//        accessibilityFeature.setNearestOSWElements(nearestOSWElements: nearestOSWElements)
        locationType == .captureLocation ? accessibilityFeature.setNearestOSWElements(nearestOSWElements: nearestOSWElements) : accessibilityFeature.setCorrectedNearestOSWElements(nearestOSWElements)
    }
    
    func processLocationRequestTypeBased(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: MappedEditableAccessibilityFeature,
        locationType: LocationType = .captureLocation,
    ) throws {
        let locationRequestResult = try self.calculateLocation(
            deviceLocation: deviceLocation,
            accessibilityFeature: accessibilityFeature
        )
//        accessibilityFeature.setLocationDetails(locationDetails: locationRequestResult.locationDetails)
        locationType == .captureLocation ? accessibilityFeature.setLocationDetails(locationDetails: locationRequestResult.locationDetails) : accessibilityFeature.setCorrectedLocationDetails(locationRequestResult.locationDetails)
        /// Set Lidar Depth as experimental attribute
        if locationType == .captureLocation {
            if let lidarDepthAttributeValue = AccessibilityFeatureAttribute.lidarDepth.value(
                from: Double(locationRequestResult.lidarDepth)
            ) {
                do {
                    try accessibilityFeature.setExperimentalAttributeValue(lidarDepthAttributeValue, for: .lidarDepth)
                } catch {
                    print("Error setting lidar depth attribute for feature \(accessibilityFeature.id): \(error.localizedDescription)")
                }
            }
            if let latitudeDeltaAttributeValue = AccessibilityFeatureAttribute.latitudeDelta.value(
                from: Double(locationRequestResult.locationDelta.x)
            ) {
                do {
                    try accessibilityFeature.setExperimentalAttributeValue(latitudeDeltaAttributeValue, for: .latitudeDelta)
                } catch {
                    print("Error setting latitude delta attribute for feature " +
                          "\(accessibilityFeature.id): \(error.localizedDescription)")
                }
            }
            if let longitudeDeltaAttributeValue = AccessibilityFeatureAttribute.longitudeDelta.value(
                from: Double(locationRequestResult.locationDelta.y)
            ) {
                do {
                    try accessibilityFeature.setExperimentalAttributeValue(longitudeDeltaAttributeValue, for: .longitudeDelta)
                } catch {
                    print("Error setting longitude delta attribute for feature " +
                          "\(accessibilityFeature.id): \(error.localizedDescription)")
                }
            }
        }
    }
}

/**
 This unique extension is used to process all the features of a specific class at once for the above multiple requests.
 This is to ensure that each feature gets assigned to a unique OSW element and not multiple features getting assigned to the same OSW element, which can happen if each feature is processed independently.
 */
extension AttributeEstimationPipeline {
    func processAllFeaturesForAssignments(
//        deviceLocation: CLLocationCoordinate2D,
        captureLocation: CLLocationCoordinate2D,
        correctedLocation: CLLocationCoordinate2D?,
        mappingData: CurrentMappingData,
        accessibilityFeatures: [MappedEditableAccessibilityFeature]
    ) throws {
        let correctedLocation = correctedLocation ?? captureLocation
        /// First, calculate all the feature locations
        for feature in accessibilityFeatures {
            try self.processLocationRequestTypeBased(
                deviceLocation: captureLocation,
                accessibilityFeature: feature,
                locationType: .captureLocation
            )
            try self.processLocationRequestTypeBased(
                deviceLocation: correctedLocation,
                accessibilityFeature: feature,
                locationType: .correctedLocation
            )
        }
        /// Second, get all the nearest elements (existing features) for each feature
        for feature in accessibilityFeatures {
            self.processNearestFeaturesRequest(
                deviceLocation: captureLocation,
                mappingData: mappingData,
                accessibilityFeature: feature,
                locationType: .captureLocation
            )
            self.processNearestFeaturesRequest(
                deviceLocation: correctedLocation,
                mappingData: mappingData,
                accessibilityFeature: feature,
                locationType: .correctedLocation
            )
        }
        /// Third, get all the nearest features (element, total distance, total feature matches)
        var captureNearestFeatures: [(any OSWElement, Float, Int)] = []
        var correctedNearestFeatures: [(any OSWElement, Float, Int)] = []
        for feature in accessibilityFeatures {
            if let nearestElements = feature.nearestOSWElements {
                for (element, distance) in nearestElements {
                    if let index = captureNearestFeatures.firstIndex(where: { $0.0.id == element.id }) {
                        captureNearestFeatures[index].1 += Float(distance)
                        captureNearestFeatures[index].2 += 1
                    } else {
                        captureNearestFeatures.append((element, Float(distance), 1))
                    }
                }
            }
            if let correctedNearestElements = feature.correctedNearestOSWElements {
                for (element, distance) in correctedNearestElements {
                    if let index = correctedNearestFeatures.firstIndex(where: { $0.0.id == element.id }) {
                        correctedNearestFeatures[index].1 += Float(distance)
                        correctedNearestFeatures[index].2 += 1
                    } else {
                        correctedNearestFeatures.append((element, Float(distance), 1))
                    }
                }
            }
        }
        /// Now, sort all the nearest features with the following rules
        /// If capture id matches, assign priority to that feature
        /// Then, sort the matched features by average distance ascending, then sort the non-matched features by average distance ascending
        /// Then, combine the two lists, with matched features first, then non-matched features
        let captureId = self.captureImageData?.id.uuidString
        let sortedCaptureNearestFeatures = captureNearestFeatures.sorted {
            (feature1: (any OSWElement, Float, Int), feature2: (any OSWElement, Float, Int)) -> Bool in
            if feature1.0.getCaptureId() == captureId && feature2.0.getCaptureId() != captureId {
                return true
            } else if feature1.0.getCaptureId() != captureId && feature2.0.getCaptureId() == captureId {
                return false
            } else {
                let avgDistance1 = feature1.1 / Float(feature1.2)
                let avgDistance2 = feature2.1 / Float(feature2.2)
                return avgDistance1 < avgDistance2
            }
        }
        let sortedCorrectedNearestFeatures = correctedNearestFeatures.sorted {
            (feature1: (any OSWElement, Float, Int), feature2: (any OSWElement, Float, Int)) -> Bool in
            if feature1.0.getCaptureId() == captureId && feature2.0.getCaptureId() != captureId {
                return true
            } else if feature1.0.getCaptureId() != captureId && feature2.0.getCaptureId() == captureId {
                return false
            } else {
                let avgDistance1 = feature1.1 / Float(feature1.2)
                let avgDistance2 = feature2.1 / Float(feature2.2)
                return avgDistance1 < avgDistance2
            }
        }
        
        /// Now, do a first-come first-serve matching, where each existing feature is matched to the new features
        /// We will iterate through the sorted nearest features and assign them to the new features, ensuring that each existing feature is only assigned to one new feature.
        /// Both the oswElement and correctedOSWElement for now will be assigned using sortedCorrectedNearestFeatures
        /// Also update the new feature with the isExisting and isCaptureMatched flag.
        var unassignedFeatures = accessibilityFeatures
        for sortedCorrectedNearestFeature in sortedCorrectedNearestFeatures {
            print("Capture id comparison: \(sortedCorrectedNearestFeature.0.getCaptureId()) == \(captureId)")
            let isCaptureMatched = sortedCorrectedNearestFeature.0.getCaptureId() == captureId
            var nearestCandidateFeatures: [(MappedEditableAccessibilityFeature, Float)] = []
            for feature in unassignedFeatures {
                if let nearestElements = feature.correctedNearestOSWElements {
                    /// Check if the current sortedCorrectedNearestFeature is in the nearestElements of the feature
                    /// and get the distance
                    if let distance = nearestElements.first(where: { $0.0.id == sortedCorrectedNearestFeature.0.id })?.1 {
                        nearestCandidateFeatures.append((feature, Float(distance)))
                    }
                }
            }
            /// Now, sort the nearestCandidateFeatures by distance ascending
            nearestCandidateFeatures.sort { $0.1 < $1.1 }
            /// Now, assign the nearestCandidateFeatures to the sortedCorrectedNearestFeature, ensuring that each existing feature is only assigned to one new feature.
            if let nearestCandidateFeature = nearestCandidateFeatures.first {
                let feature = nearestCandidateFeature.0
                feature.isCaptureMatched = isCaptureMatched
                feature.setIsExisting(true)
                feature.setOSWElement(oswElement: sortedCorrectedNearestFeature.0)
                feature.setCorrectedIsExisting(true)
                feature.setCorrectedOSWElement(sortedCorrectedNearestFeature.0)
                /// Now, remove the assigned feature from the unassignedFeatures list
                if let index = unassignedFeatures.firstIndex(where: { $0.id == feature.id }) {
                    unassignedFeatures.remove(at: index)
                }
            }
        }
        /// For the remaining unassigned features, set them as non-existing and remove any existing oswElement or correctedOSWElement
        for feature in unassignedFeatures {
            feature.setIsExisting(false)
            feature.setOSWElement(oswElement: nil)
            feature.setCorrectedIsExisting(false)
            feature.setCorrectedOSWElement(nil)
        }
    }
}
