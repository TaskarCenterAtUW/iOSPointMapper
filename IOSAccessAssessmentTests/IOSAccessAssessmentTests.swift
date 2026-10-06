//
//  IOSAccessAssessmentTests.swift
//  IOSAccessAssessmentTests
//
//  Created by Sai on 1/24/24.
//

import XCTest
@testable import IOSAccessAssessment
import PointNMapShared

final class IOSAccessAssessmentTests: XCTestCase {
    func testCustomOSWFieldPreservesMetadata() {
        let field = OSWField.custom("Temporary walkway", "highway")
        print("Osm Tag Key: ", field.osmTagKey)

        XCTAssertEqual(field.description, "Temporary walkway")
        XCTAssertEqual(field.osmTagKey, "highway")
    }

    func testSlidingWindowGridUsesPlaneCoordinatesAndIJOrdering() throws {
        let result = try SurfaceIntegrityProcessor.computeGridIndices(
            meshCentroids: [SIMD3<Float>(0.01, 0.01, 0), SIMD3<Float>(0.20, 0.10, 0)],
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            stride: 0.09
        )

        XCTAssertEqual(result.gridOriginU, 0, accuracy: 0.000_001)
        XCTAssertEqual(result.gridOriginV, 0, accuracy: 0.000_001)
        XCTAssertEqual(result.gridShape, SIMD2<Int32>(3, 2))
        XCTAssertEqual(result.gridIndices, [
            SIMD2<Int32>(0, 0), SIMD2<Int32>(0, 1),
            SIMD2<Int32>(1, 0), SIMD2<Int32>(1, 1),
            SIMD2<Int32>(2, 0), SIMD2<Int32>(2, 1)
        ])
        XCTAssertEqual(result.uvCoordinates[1].x, 0.20, accuracy: 0.000_001)
        XCTAssertEqual(result.uvCoordinates[1].y, 0.10, accuracy: 0.000_001)
    }

    func testSlidingWindowGridSnapsNegativeOriginsDownToStrideBoundary() throws {
        let result = try SurfaceIntegrityProcessor.computeGridIndices(
            meshCentroids: [SIMD3<Float>(-0.01, -0.10, 0)],
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            stride: 0.09
        )

        XCTAssertEqual(result.gridOriginU, -0.09, accuracy: 0.000_001)
        XCTAssertEqual(result.gridOriginV, -0.18, accuracy: 0.000_001)
    }

    func testSlidingWindowBoundsConvertPlaneCoordinatesToWorldCorners() throws {
        let result = try SurfaceIntegrityProcessor.computeGridBounds(
            gridIndices: [SIMD2<Int32>(1, 2)],
            gridOriginU: 0,
            gridOriginV: 0,
            planeOrigin: SIMD3<Float>(10, 20, 30),
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 0, 1),
            cellSize: 0.27,
            stride: 0.09
        )

        XCTAssertEqual(result.bounds[0].minU, 0.09, accuracy: 0.000_001)
        XCTAssertEqual(result.bounds[0].maxU, 0.36, accuracy: 0.000_001)
        XCTAssertEqual(result.bounds[0].minV, 0.18, accuracy: 0.000_001)
        XCTAssertEqual(result.bounds[0].maxV, 0.45, accuracy: 0.000_001)
        let expectedCorners = [
            SIMD3<Float>(10.09, 20, 30.18),
            SIMD3<Float>(10.36, 20, 30.18),
            SIMD3<Float>(10.36, 20, 30.45),
            SIMD3<Float>(10.09, 20, 30.45)
        ]
        for (actual, expected) in zip(result.bounds3D[0], expectedCorners) {
            XCTAssertEqual(actual.x, expected.x, accuracy: 0.000_001)
            XCTAssertEqual(actual.y, expected.y, accuracy: 0.000_001)
            XCTAssertEqual(actual.z, expected.z, accuracy: 0.000_001)
        }
    }

    func testSlidingWindowMembershipUsesHalfOpenBounds() throws {
        let grid = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: [SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.27, 0, 0)],
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            cellSize: 0.27,
            stride: 0.09
        )

        XCTAssertEqual(grid.gridShape, SIMD2<Int32>(4, 1))
        guard let firstMembership = grid.windowToMeshIndices.first,
              let lastMembership = grid.windowToMeshIndices.last else {
            XCTFail("Expected the grid to contain windows")
            return
        }
        XCTAssertEqual(firstMembership, [0])
        XCTAssertEqual(lastMembership, [1])
    }

    func testSlidingWindowGridFiltersWindowsBelowMinimumMeshPointCount() throws {
        let grid = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: [SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.01, 0.01, 0)],
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            includeEmptyWindows: false,
            minMeshPoints: 2
        )

        XCTAssertEqual(grid.gridIndices, [SIMD2<Int32>(0, 0)])
        XCTAssertEqual(grid.windowToMeshIndices, [[0, 1]])
    }

    func testPolygonProjectionToPlaneUsesPlaneBasis() {
        let result = SurfaceIntegrityProcessor.projectPolygonToPlane(
            [SIMD3<Float>(11, 20, 32), SIMD3<Float>(12, 20, 34)],
            planeOrigin: SIMD3<Float>(10, 20, 30),
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 0, 1)
        )

        XCTAssertEqual(result, [SIMD2<Float>(1, 2), SIMD2<Float>(2, 4)])
    }

    func testGridWindowProjectionProjectsEveryCorner() {
        let result = SurfaceIntegrityProcessor.projectGridWindowsToPlane(
            [[
                SIMD3<Float>(10, 20, 30),
                SIMD3<Float>(11, 20, 30),
                SIMD3<Float>(11, 20, 32),
                SIMD3<Float>(10, 20, 32)
            ]],
            planeOrigin: SIMD3<Float>(10, 20, 30),
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 0, 1)
        )

        XCTAssertEqual(result, [[
            SIMD2<Float>(0, 0), SIMD2<Float>(1, 0),
            SIMD2<Float>(1, 2), SIMD2<Float>(0, 2)
        ]])
    }

    func testPolygonOverlapUsesComparisonUnionWithoutDoubleCounting() {
        let base = rectangle(minX: 0, minY: 0, maxX: 2, maxY: 2)
        let comparisons = [
            rectangle(minX: 0, minY: 0, maxX: 1.5, maxY: 2),
            rectangle(minX: 0.5, minY: 0, maxX: 2, maxY: 2)
        ]

        let result = SurfaceIntegrityProcessor.checkOverlapBetweenPolygons(
            polygonBase: base,
            polygonsCompare: comparisons,
            severityCompare: [0.4, 0.8]
        )

        XCTAssertEqual(result.overlapRatio, 1, accuracy: 0.000_001)
        XCTAssertEqual(result.maximumSeverity, 0.8, accuracy: 0.000_001)
    }

    func testPolygonOverlapIgnoresSeverityOfNonIntersectingPolygon() {
        let result = SurfaceIntegrityProcessor.checkOverlapBetweenPolygons(
            polygonBase: rectangle(minX: 0, minY: 0, maxX: 1, maxY: 1),
            polygonsCompare: [
                rectangle(minX: 0.5, minY: 0, maxX: 1.5, maxY: 1),
                rectangle(minX: 2, minY: 2, maxX: 3, maxY: 3)
            ],
            severityCompare: [0.4, 0.99]
        )

        XCTAssertEqual(result.overlapRatio, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(result.maximumSeverity, 0.4, accuracy: 0.000_001)
    }

    func testMeshSurfaceDetailsNormalizeNormalsAndDiscardInvalidRows() throws {
        let details = try SurfaceIntegrityProcessor.getSurfaceDetailsFromMesh(
            centroids: [SIMD3<Float>(1, 2, 3), SIMD3<Float>(4, 5, 6)],
            normals: [SIMD3<Float>(1, 0, 1), SIMD3<Float>(.nan, 0, 0)],
            areas: [0.2, 0.4],
            planeNormal: SIMD3<Float>(0, 0, 1)
        )

        XCTAssertEqual(details.count, 1)
        XCTAssertEqual(details[0].centroid, SIMD3<Float>(1, 2, 3))
        XCTAssertEqual(details[0].normal.x, sqrt(0.5), accuracy: 0.000_001)
        XCTAssertEqual(details[0].normal.z, sqrt(0.5), accuracy: 0.000_001)
        XCTAssertEqual(details[0].area, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(details[0].angularDeviationDegrees, 45, accuracy: 0.000_01)
    }

    func testHeightResidualsPreserveSideOfPlane() {
        let details = [
            MeshSurfaceDetail(
                centroid: SIMD3<Float>(0, 0, 3),
                normal: SIMD3<Float>(0, 0, 1),
                area: 1,
                angularDeviationDegrees: 0
            ),
            MeshSurfaceDetail(
                centroid: SIMD3<Float>(0, 0, -1),
                normal: SIMD3<Float>(0, 0, 1),
                area: 1,
                angularDeviationDegrees: 0
            )
        ]

        let residuals = SurfaceIntegrityProcessor.calculateHeightResiduals(
            surfaceDetails: details,
            planeOrigin: SIMD3<Float>(0, 0, 1),
            planeNormal: SIMD3<Float>(0, 0, 1)
        )

        XCTAssertEqual(residuals, [2, -2])
    }

    func testSignedTiltMatchesPythonFeatureDefinition() throws {
        let details = [
            MeshSurfaceDetail(
                centroid: .zero,
                normal: SIMD3<Float>(1, 0, 1),
                area: 1,
                angularDeviationDegrees: 45
            )
        ]

        let tilt = try SurfaceIntegrityProcessor.calculateSignedTiltData(
            surfaceDetails: details,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            planeNormal: SIMD3<Float>(0, 0, 1)
        )

        XCTAssertEqual(tilt[0].tiltUDegrees, 45, accuracy: 0.000_01)
        XCTAssertEqual(tilt[0].tiltVDegrees, 0, accuracy: 0.000_01)
        XCTAssertEqual(tilt[0].tiltMagnitudeDegrees, 45, accuracy: 0.000_01)
    }

    func testWeightedPercentileMatchesNumPyInterpolation() {
        let percentile = SurfaceIntegrityProcessor.weightedPercentile(
            values: [0, 10],
            weights: [1, 3],
            percentile: 50
        )

        XCTAssertEqual(percentile, 10.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(
            SurfaceIntegrityProcessor.weightedPercentile(
                values: [0, 10],
                weights: [1, 3],
                percentile: 0
            ),
            0
        )
        XCTAssertEqual(
            SurfaceIntegrityProcessor.weightedPercentile(
                values: [0, 10],
                weights: [1, 3],
                percentile: 100
            ),
            10
        )
    }

    func testWindowFeaturesMatchConfiguredStatistics() throws {
        let details = [
            MeshSurfaceDetail(
                centroid: .zero,
                normal: SIMD3<Float>(0, 0, 1),
                area: 1,
                angularDeviationDegrees: 0
            ),
            MeshSurfaceDetail(
                centroid: .zero,
                normal: SIMD3<Float>(0, 0, 1),
                area: 3,
                angularDeviationDegrees: 10
            )
        ]
        let tilts = [
            SignedTiltData(tiltUDegrees: 3, tiltVDegrees: 4, tiltMagnitudeDegrees: 0),
            SignedTiltData(tiltUDegrees: 0, tiltVDegrees: 0, tiltMagnitudeDegrees: 12)
        ]

        let features = try SurfaceIntegrityProcessor.processWindowFeatures(
            surfaceDetails: details,
            heightResiduals: [-1, 3],
            signedTiltData: tilts,
            heightFromGround: 1.25
        )

        XCTAssertEqual(features[.numberOfPolygons], 2)
        XCTAssertEqual(features[.totalSidewalkArea], 4)
        XCTAssertEqual(features[.averagePolygonArea], 2)
        XCTAssertEqual(features[.polygonDensity], 0.5)
        XCTAssertEqual(features[.heightFromGround], 1.25)
        XCTAssertEqual(features[.normalDeviationMean], 5)
        XCTAssertEqual(features[.normalDeviationMedian], 10.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(features[.normalDeviationProportionAbove5], 0.75)
        XCTAssertEqual(features[.heightResidualsStandardDeviation], 2)
        XCTAssertEqual(features[.heightResidualsAbsoluteMean], 2)
        XCTAssertEqual(features[.signedTiltMagnitudeMean], 8.5)
    }

    func testEmptyWindowFeaturesUsePlaceholders() throws {
        let features = try SurfaceIntegrityProcessor.processWindowFeatures(
            surfaceDetails: [],
            heightResiduals: [],
            signedTiltData: [],
            heightFromGround: nil
        )

        XCTAssertEqual(features.values.count, SurfaceIntegrityWindowFeature.allCases.count)
        for feature in SurfaceIntegrityWindowFeature.allCases where feature != .heightFromGround {
            XCTAssertEqual(features[feature], 0)
        }
        XCTAssertTrue(features[.heightFromGround].isNaN)
    }

    private func rectangle(minX: Float, minY: Float, maxX: Float, maxY: Float) -> [SIMD2<Float>] {
        [
            SIMD2<Float>(minX, minY), SIMD2<Float>(maxX, minY),
            SIMD2<Float>(maxX, maxY), SIMD2<Float>(minX, maxY)
        ]
    }

}
