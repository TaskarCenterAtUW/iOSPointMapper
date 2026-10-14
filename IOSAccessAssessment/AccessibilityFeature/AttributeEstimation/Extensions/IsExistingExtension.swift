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
        guard let locationDetails = accessibilityFeature.locationDetails else {
            accessibilityFeature.setRelevantOSWElements([])
            try? accessibilityFeature.applyOSWElementSelection(.newElement)
            return
        }
        let candidates = mappingData.getRelevantFeatures(
            to: locationDetails,
            featureClass: accessibilityFeature.accessibilityFeatureClass,
            captureId: self.captureImageData?.id,
            distanceThreshold: distanceThreshold
        )
        accessibilityFeature.setRelevantOSWElements(candidates)
        guard let firstCandidate = candidates.first,
              accessibilityFeature.accessibilityFeatureClass.kind.oswPolicy.isExistingFirst else {
            try? accessibilityFeature.applyOSWElementSelection(.newElement)
            return
        }
        try? accessibilityFeature.applyOSWElementSelection(
            .existingElement(id: firstCandidate.id)
        )
    }
}
