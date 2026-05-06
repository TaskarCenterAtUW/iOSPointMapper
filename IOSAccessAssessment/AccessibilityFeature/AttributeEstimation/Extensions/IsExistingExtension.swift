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
}
