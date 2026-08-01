//
//  IsExistingExtension.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/30/26.
//
import PointNMapShared
import CoreLocation
import MapKit

extension AttributeEstimationPipeline {
    func processIsExistingRequest(
        deviceLocation: CLLocationCoordinate2D,
        mappingData: CurrentMappingData,
        accessibilityFeature: MappedEditableAccessibilityFeature
    ) {
        /// Threshold needs to be in Map Units
        let distanceThreshold = PointNMapConstants.WorkspaceConstants.fetchUpdateRadiusThresholdInMeters * MKMapPointsPerMeterAtLatitude(deviceLocation.latitude)
        guard let LocationDetails = accessibilityFeature.locationDetails else {
            accessibilityFeature.setIsExisting(false)
            return
        }
        let matchedElement: (any OSWElement)? = mappingData.getMatchedFeature(
            to: LocationDetails, featureClass: accessibilityFeature.accessibilityFeatureClass,
            captureId: self.captureImageData?.id,
            distanceThreshold: distanceThreshold
        )
        guard let matchedElement = matchedElement else {
            accessibilityFeature.setIsExisting(false)
            return
        }
        let isExisting = accessibilityFeature.accessibilityFeatureClass.kind.oswPolicy.isExistingFirst
        accessibilityFeature.setIsExisting(isExisting)
        accessibilityFeature.setOSWElement(oswElement: matchedElement)
    }
    
    func processNearestFeaturesRequest(
        deviceLocation: CLLocationCoordinate2D,
        mappingData: CurrentMappingData,
        accessibilityFeature: MappedEditableAccessibilityFeature
    ) {
        /// Threshold needs to be in Map Units
        let distanceThreshold = PointNMapConstants.WorkspaceConstants.fetchUpdateRadiusThresholdInMeters * MKMapPointsPerMeterAtLatitude(deviceLocation.latitude)
        guard let LocationDetails = accessibilityFeature.locationDetails else {
            return
        }
        let nearestOSWElements: [(any OSWElement, CLLocationDistance)] = mappingData.getNearestFeatures(
            to: LocationDetails, featureClass: accessibilityFeature.accessibilityFeatureClass,
            distanceThreshold: distanceThreshold
        )
        accessibilityFeature.setNearestOSWElements(nearestOSWElements: nearestOSWElements)
    }
    
    public func processCorrectedLocationRequest(
        deviceLocation: CLLocationCoordinate2D,
        accessibilityFeature: any EditableAccessibilityFeatureProtocol
    ) throws {
        let locationRequestResult = try self.calculateLocation(
            deviceLocation: deviceLocation,
            accessibilityFeature: accessibilityFeature
        )
        accessibilityFeature.setLocationDetails(locationDetails: locationRequestResult.locationDetails)
        /// Set Lidar Depth as experimental attribute
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
