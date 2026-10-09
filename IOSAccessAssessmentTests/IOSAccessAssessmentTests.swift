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
    func testVisibleMapRectUsesMinimumSpanForSingleCoordinate() {
        let location = pointLocation(CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3))
        let rect = OSWElementMapViewport.makeVisibleMapRect(candidates: [], capturedFeatureLocation: location)

        XCTAssertNotNil(rect)
        XCTAssertGreaterThan(rect?.width ?? 0, 0)
        XCTAssertGreaterThan(rect?.height ?? 0, 0)
    }

    func testVisibleMapRectReturnsNilForNoCoordinates() {
        XCTAssertNil(OSWElementMapViewport.makeVisibleMapRect(candidates: [], capturedFeatureLocation: LocationDetails(locations: [])))
    }

    func testVisibleMapRectUsesWrappedLongitudeSpanAcrossAntimeridian() throws {
        let featureClass = try pointFeatureClass()
        let east = CLLocationCoordinate2D(latitude: 0, longitude: 179.999)
        let west = CLLocationCoordinate2D(latitude: 0, longitude: -179.999)
        let candidate = OSWElementCandidate(element: makePoint(id: "west", coordinate: west, featureClass: featureClass), locationDetails: pointLocation(west), distance: 0, isCaptureMatched: false)

        let rect = try XCTUnwrap(OSWElementMapViewport.makeVisibleMapRect(candidates: [candidate], capturedFeatureLocation: pointLocation(east)))

        XCTAssertLessThan(rect.width, MKMapSize.world.width / 100)
    }
    func testRelevantLineStringCandidateResolvesNodeCoordinatesInReferenceOrder() throws {
        let featureClass = try featureClass(geometry: .linestring)
        let origin = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
        let mappingData = CurrentMappingData()
        let first = makePoint(id: "first", coordinate: origin, featureClass: featureClass)
        let second = makePoint(id: "second", coordinate: offset(origin, northMeters: 5), featureClass: featureClass)
        mappingData.points = [first.id: first, second.id: second]
        mappingData.updateFeatures([makeLine(id: "line", pointRefs: [first.id, second.id], featureClass: featureClass)], for: featureClass)

        let candidate = try XCTUnwrap(mappingData.getRelevantFeatures(to: wayLocation([origin, CLLocationCoordinate2D(latitude: second.latitude, longitude: second.longitude)], isClosed: false), featureClass: featureClass, captureId: nil).first)

        XCTAssertEqual(candidate.locationDetails.locations.first?.coordinates.map(\.latitude), [first.latitude, second.latitude])
    }

    func testRelevantPolygonCandidateAcceptsRepeatedClosingCoordinate() throws {
        let featureClass = try featureClass(geometry: .polygon)
        let origin = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
        let mappingData = CurrentMappingData()
        let points = [
            makePoint(id: "a", coordinate: origin, featureClass: featureClass),
            makePoint(id: "b", coordinate: offset(origin, northMeters: 4), featureClass: featureClass),
            makePoint(id: "c", coordinate: CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude + 0.00005), featureClass: featureClass)
        ]
        mappingData.points = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
        mappingData.updateFeatures([makePolygon(id: "polygon", pointRefs: ["a", "b", "c", "a"], featureClass: featureClass)], for: featureClass)

        let candidates = mappingData.getRelevantFeatures(to: wayLocation(points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }, isClosed: true), featureClass: featureClass, captureId: nil)

        XCTAssertEqual(candidates.first?.id, "polygon")
        XCTAssertEqual(candidates.first?.locationDetails.locations.first?.coordinates.count, 4)
    }

    func testRelevantWayCandidateIsOmittedWhenAnyNodeIsMissing() throws {
        let featureClass = try featureClass(geometry: .linestring)
        let origin = CLLocationCoordinate2D(latitude: 47.6062, longitude: -122.3321)
        let mappingData = CurrentMappingData()
        let point = makePoint(id: "present", coordinate: origin, featureClass: featureClass)
        mappingData.points[point.id] = point
        mappingData.updateFeatures([makeLine(id: "invalid", pointRefs: [point.id, "missing"], featureClass: featureClass)], for: featureClass)

        XCTAssertTrue(mappingData.getRelevantFeatures(to: pointLocation(origin), featureClass: featureClass, captureId: nil).isEmpty)
    }

    func testExistingElementSelectionResolvesCandidateAndUnknownIdThrows() throws {
        let featureClass = try pointFeatureClass()
        let point = makePoint(id: "point", coordinate: CLLocationCoordinate2D(latitude: 47.6, longitude: -122.3), featureClass: featureClass)
        let candidate = OSWElementCandidate(element: point, locationDetails: pointLocation(CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)), distance: 0, isCaptureMatched: false)

        XCTAssertEqual(try OSWElementSelection.existingElement(id: point.id).resolve(in: [candidate])?.id, point.id)
        XCTAssertThrowsError(try OSWElementSelection.existingElement(id: "unknown").resolve(in: [candidate]))
        XCTAssertNil(try OSWElementSelection.newElement.resolve(in: [candidate]))
    }
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
        try featureClass(geometry: .point)
    }

    private func featureClass(geometry: MappingGeometry) throws -> AccessibilityFeatureClass {
        guard let featureClass = AccessibilityFeatureConfig.mapillaryCustom12Config.classes.first(where: {
            $0.kind.oswPolicy.oswElementClass.geometry == geometry
        }) else {
            throw XCTSkip("The configured accessibility feature classes contain no point geometry.")
        }
        return featureClass
    }

    private func makeLine(id: String, pointRefs: [String], featureClass: AccessibilityFeatureClass) -> OSWLineString {
        OSWLineString(id: id, version: "1", oswElementClass: featureClass.kind.oswPolicy.oswElementClass, attributeValues: [:], experimentalAttributeValues: [:], pointRefs: pointRefs)
    }

    private func makePolygon(id: String, pointRefs: [String], featureClass: AccessibilityFeatureClass) -> OSWPolygon {
        OSWPolygon(id: id, version: "1", oswElementClass: featureClass.kind.oswPolicy.oswElementClass, attributeValues: [:], experimentalAttributeValues: [:], pointRefs: pointRefs)
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

    private func wayLocation(_ coordinates: [CLLocationCoordinate2D], isClosed: Bool) -> LocationDetails {
        LocationDetails(locations: [LocationElement(coordinates: coordinates, isWay: true, isClosed: isClosed)])
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
