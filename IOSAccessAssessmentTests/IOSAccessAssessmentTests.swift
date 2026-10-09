//
//  IOSAccessAssessmentTests.swift
//  IOSAccessAssessmentTests
//
//  Created by Sai on 1/24/24.
//

import XCTest
import CoreLocation
import MapKit
import PointNMapShared
@testable import IOSAccessAssessment

final class IOSAccessAssessmentTests: XCTestCase {
    func testCustomOSWFieldPreservesMetadata() {
        let field = OSWField.custom("Temporary walkway", "highway")
        print("Osm Tag Key: ", field.osmTagKey)

        XCTAssertEqual(field.description, "Temporary walkway")
        XCTAssertEqual(field.osmTagKey, "highway")
    }

    func testRelevantFeaturesAreFilteredByDistanceAndSortedNearestFirst() throws {
        let featureClass = try pointFeatureClass()
        let origin = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
        let mappingData = CurrentMappingData()
        let nearest = makePoint(id: "nearest", coordinate: offset(origin, northMeters: 5), featureClass: featureClass)
        let farther = makePoint(id: "farther", coordinate: offset(origin, northMeters: 25), featureClass: featureClass)
        let outsideThreshold = makePoint(id: "outside", coordinate: offset(origin, northMeters: 75), featureClass: featureClass)
        mappingData.updateFeatures([outsideThreshold, farther, nearest], for: featureClass)

        let relevantFeatures = mappingData.getRelevantFeatures(
            to: pointLocation(origin),
            featureClass: featureClass,
            captureId: nil,
            distanceThreshold: 50 * MKMapPointsPerMeterAtLatitude(origin.latitude)
        )

        XCTAssertEqual(relevantFeatures.map(\.id), ["nearest", "farther"])
    }

    func testCaptureMatchedFeatureIsFirstEvenWhenOutsideDistanceThreshold() throws {
        let featureClass = try pointFeatureClass()
        let captureId = UUID()
        let origin = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
        let mappingData = CurrentMappingData()
        let nearby = makePoint(id: "nearby", coordinate: offset(origin, northMeters: 5), featureClass: featureClass)
        let captureMatched = makePoint(
            id: "capture-matched",
            coordinate: offset(origin, northMeters: 75),
            featureClass: featureClass,
            captureId: captureId
        )
        mappingData.updateFeatures([nearby, captureMatched], for: featureClass)

        let relevantFeatures = mappingData.getRelevantFeatures(
            to: pointLocation(origin),
            featureClass: featureClass,
            captureId: captureId,
            distanceThreshold: 50 * MKMapPointsPerMeterAtLatitude(origin.latitude)
        )

        XCTAssertEqual(relevantFeatures.map(\.id), ["capture-matched", "nearby"])
    }

    private func pointFeatureClass() throws -> AccessibilityFeatureClass {
        guard let featureClass = AccessibilityFeatureConfig.mapillaryCustom12Config.classes.first(where: {
            $0.kind.oswPolicy.oswElementClass.geometry == .point
        }) else {
            throw XCTSkip("The configured accessibility feature classes contain no point geometry.")
        }
        return featureClass
    }

    private func makePoint(
        id: String,
        coordinate: CLLocationCoordinate2D,
        featureClass: AccessibilityFeatureClass,
        captureId: UUID? = nil
    ) -> OSWPoint {
        var additionalTags: [String: String] = [:]
        additionalTags[APIConstants.TagKeys.captureIdKey] = captureId?.uuidString
        return OSWPoint(
            id: id,
            version: "1",
            oswElementClass: featureClass.kind.oswPolicy.oswElementClass,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            attributeValues: [:],
            experimentalAttributeValues: [:],
            additionalTags: additionalTags
        )
    }

    private func pointLocation(_ coordinate: CLLocationCoordinate2D) -> LocationDetails {
        LocationDetails(locations: [LocationElement(coordinates: [coordinate], isWay: false, isClosed: false)])
    }

    private func offset(
        _ coordinate: CLLocationCoordinate2D,
        northMeters: CLLocationDistance
    ) -> CLLocationCoordinate2D {
        let mapPoint = MKMapPoint(coordinate)
        let offsetPoint = MKMapPoint(
            x: mapPoint.x,
            y: mapPoint.y - northMeters * MKMapPointsPerMeterAtLatitude(coordinate.latitude)
        )
        return offsetPoint.coordinate
    }
}
