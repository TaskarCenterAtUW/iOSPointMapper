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

        XCTAssertEqual(grid.windowToMeshIndices[0], [0])
        XCTAssertEqual(grid.windowToMeshIndices[3], [1])
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

}
