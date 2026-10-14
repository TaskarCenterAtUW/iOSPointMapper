//
//  IOSAccessAssessmentTests.swift
//  IOSAccessAssessmentTests
//
//  Created by Sai on 1/24/24.
//

import Foundation
import XCTest
@testable import IOSAccessAssessment
@testable import PointNMapShared
import PointNMapShaderTypes

final class IOSAccessAssessmentTests: XCTestCase {
    func testPrerequisiteCacheReusesDamageDetectionResults() throws {
        var cache = AttributeEstimationPipeline.PrerequisiteCache()
        var computationCount = 0
        let expected = [DamageDetectionResult(
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            confidence: 0.8,
            label: "damage"
        )]

        let first = cache.getOrCompute(\.damageDetectionResults) {
            computationCount += 1
            return expected
        }
        let second = cache.getOrCompute(\.damageDetectionResults) {
            computationCount += 1
            return []
        }

        XCTAssertEqual(first, expected)
        XCTAssertEqual(second, expected)
        XCTAssertEqual(computationCount, 1)
    }

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

    func testSlidingWindowGridCSRDescribesEachWindowMembershipRange() throws {
        let grid = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: [SIMD3<Float>(0, 0, 0), SIMD3<Float>(0.27, 0, 0)],
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            cellSize: 0.27,
            stride: 0.09
        )

        XCTAssertEqual(grid.membershipCSR.windowOffsets, [0, 1, 2, 3, 4])
        XCTAssertEqual(grid.membershipCSR.meshIndices, [0, 1, 1, 1])
        XCTAssertEqual(grid.membershipCSR.windowCount, 4)
        XCTAssertEqual(grid.membershipCSR.membershipCount, 4)
    }

    func testMetalSlidingWindowMembershipCountsAndCPUOffsetsMatchCPUGrid() throws {
        let centroids = [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0.089_999, 0.09, 0),
            SIMD3<Float>(0.09, 0.18, 0),
            SIMD3<Float>(0.269_999, 0.27, 0),
            SIMD3<Float>(0.27, 0.36, 0)
        ]
        let indexResult = try SurfaceIntegrityProcessor.computeGridIndices(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            stride: 0.09
        )
        let cpuGrid = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            cellSize: 0.27,
            stride: 0.09
        )
        let processor = try SurfaceIntegrityProcessor()

        let result = try processor.computeSlidingWindowMembershipCounts(
            uvCoordinates: indexResult.uvCoordinates,
            gridOriginU: indexResult.gridOriginU,
            gridOriginV: indexResult.gridOriginV,
            gridShape: indexResult.gridShape,
            cellSize: 0.27,
            stride: 0.09
        )
        let expectedCounts = zip(
            cpuGrid.membershipCSR.windowOffsets,
            cpuGrid.membershipCSR.windowOffsets.dropFirst()
        ).map { $1 - $0 }

        XCTAssertEqual(result.windowCounts, expectedCounts)
        XCTAssertEqual(result.windowOffsets, cpuGrid.membershipCSR.windowOffsets)
        XCTAssertEqual(result.membershipCount, cpuGrid.membershipCSR.membershipCount)
    }

    func testMetalSlidingWindowScatterMatchesSortedCPUMemberships() throws {
        var state: UInt64 = 0x51CA_77E2
        var centroids = (0..<1_000).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let u = Float(state & 0xFFFF) / Float(UInt16.max) * 1.8 - 0.45
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let v = Float(state & 0xFFFF) / Float(UInt16.max) * 1.35 - 0.27
            return SIMD3<Float>(u, v, 0)
        }
        centroids.append(contentsOf: [
            SIMD3<Float>(-0.45, -0.27, 0),
            SIMD3<Float>(-0.000_001, 0, 0),
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0.089_999, 0.09, 0),
            SIMD3<Float>(0.09, 0.18, 0),
            SIMD3<Float>(0.269_999, 0.27, 0),
            SIMD3<Float>(0.27, 0.36, 0)
        ])
        let indexResult = try SurfaceIntegrityProcessor.computeGridIndices(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            stride: 0.09
        )
        let cpuGrid = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            cellSize: 0.27,
            stride: 0.09
        )
        let processor = try SurfaceIntegrityProcessor()

        let gpuMembership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: indexResult.uvCoordinates,
            gridOriginU: indexResult.gridOriginU,
            gridOriginV: indexResult.gridOriginV,
            gridShape: indexResult.gridShape,
            cellSize: 0.27,
            stride: 0.09
        )
        let gpuCSR = try processor.materializeSlidingWindowMembershipForCPU(gpuMembership)
            .membershipCSR

        XCTAssertEqual(gpuCSR.windowOffsets, cpuGrid.membershipCSR.windowOffsets)
        XCTAssertEqual(gpuCSR.windowCount, cpuGrid.membershipCSR.windowCount)
        XCTAssertEqual(gpuCSR.membershipCount, cpuGrid.membershipCSR.membershipCount)
        for windowIndex in 0..<gpuCSR.windowCount {
            let cpuStart = Int(cpuGrid.membershipCSR.windowOffsets[windowIndex])
            let cpuEnd = Int(cpuGrid.membershipCSR.windowOffsets[windowIndex + 1])
            let gpuStart = Int(gpuCSR.windowOffsets[windowIndex])
            let gpuEnd = Int(gpuCSR.windowOffsets[windowIndex + 1])
            XCTAssertEqual(
                cpuGrid.membershipCSR.meshIndices[cpuStart..<cpuEnd].sorted(),
                gpuCSR.meshIndices[gpuStart..<gpuEnd].sorted(),
                "Membership mismatch for window \(windowIndex)"
            )
        }
    }

    func testMetalSlidingWindowGridMatchesCPUGridAfterDenseConversion() throws {
        let centroids = [
            SIMD3<Float>(-0.09, -0.09, 0),
            SIMD3<Float>(-0.000_001, 0, 0),
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0.089_999, 0.09, 0),
            SIMD3<Float>(0.09, 0.18, 0),
            SIMD3<Float>(0.269_999, 0.27, 0),
            SIMD3<Float>(0.27, 0.36, 0)
        ]
        let processor = try SurfaceIntegrityProcessor()
        let cpuGrid = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            includeEmptyWindows: false,
            minMeshPoints: 2
        )

        let gpuGrid = try processor.computeSlidingWindowGridUsingMetalMembership(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            includeEmptyWindows: false,
            minMeshPoints: 2
        )

        XCTAssertEqual(gpuGrid.gridIndices, cpuGrid.gridIndices)
        XCTAssertEqual(gpuGrid.gridBounds, cpuGrid.gridBounds)
        XCTAssertEqual(gpuGrid.predictionCellBounds, cpuGrid.predictionCellBounds)
        XCTAssertEqual(
            gpuGrid.windowToMeshIndices.map { $0.sorted() },
            cpuGrid.windowToMeshIndices.map { $0.sorted() }
        )
        XCTAssertEqual(gpuGrid.membershipCSR.windowOffsets, cpuGrid.membershipCSR.windowOffsets)
    }

    func testMetalSlidingWindowMembershipBuffersMaterializeCPUCSR() throws {
        let centroids = [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0.09, 0.09, 0),
            SIMD3<Float>(0.18, 0.18, 0)
        ]
        let indexResult = try SurfaceIntegrityProcessor.computeGridIndices(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            stride: 0.09
        )
        let processor = try SurfaceIntegrityProcessor()

        let gpuMembership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: indexResult.uvCoordinates,
            gridOriginU: indexResult.gridOriginU,
            gridOriginV: indexResult.gridOriginV,
            gridShape: indexResult.gridShape
        )
        let cpuCompatibility = try processor.materializeSlidingWindowMembershipForCPU(
            gpuMembership
        )
        let materialized = cpuCompatibility.membershipCSR
        let cpuGrid = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0)
        )

        XCTAssertEqual(gpuMembership.windowCount, cpuGrid.membershipCSR.windowCount)
        XCTAssertEqual(gpuMembership.membershipCount, cpuGrid.membershipCSR.membershipCount)
        XCTAssertEqual(
            gpuMembership.windowOffsetsBuffer.length,
            MemoryLayout<UInt32>.stride * (gpuMembership.windowCount + 1)
        )
        XCTAssertEqual(
            gpuMembership.meshIndicesBuffer.length,
            MemoryLayout<UInt32>.stride * gpuMembership.membershipCount
        )
        XCTAssertEqual(materialized.windowOffsets, cpuGrid.membershipCSR.windowOffsets)
        XCTAssertEqual(
            cpuCompatibility.windowToMeshIndices.map { $0.sorted() },
            cpuGrid.windowToMeshIndices.map { $0.sorted() }
        )
        for windowIndex in 0..<materialized.windowCount {
            let materializedRange = Int(materialized.windowOffsets[windowIndex])..<Int(
                materialized.windowOffsets[windowIndex + 1]
            )
            let cpuRange = Int(cpuGrid.membershipCSR.windowOffsets[windowIndex])..<Int(
                cpuGrid.membershipCSR.windowOffsets[windowIndex + 1]
            )
            XCTAssertEqual(
                materialized.meshIndices[materializedRange].sorted(),
                cpuGrid.membershipCSR.meshIndices[cpuRange].sorted()
            )
        }
    }

    func testMetalSlidingWindowGridRetainsOriginalWindowMapping() throws {
        let centroids = [
            SIMD3<Float>(-0.09, -0.09, 0),
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0.01, 0.01, 0),
            SIMD3<Float>(0.27, 0.36, 0)
        ]
        let processor = try SurfaceIntegrityProcessor()
        let unfiltered = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0)
        )

        let filtered = try processor.computeSlidingWindowGridUsingMetalMembership(
            meshCentroids: centroids,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            includeEmptyWindows: false,
            minMeshPoints: 2
        )

        XCTAssertNotNil(filtered.gpuMembership)
        XCTAssertEqual(filtered.retainedWindowIndices.count, filtered.gridIndices.count)
        XCTAssertEqual(
            filtered.retainedWindowIndices.map { unfiltered.gridIndices[$0] },
            filtered.gridIndices
        )
        XCTAssertEqual(filtered.gpuMembership?.windowCount, unfiltered.gridIndices.count)
    }

    func testInverseSlidingWindowMembershipMatchesReferenceWithFilteringAndBoundaries() throws {
        let centroids = [
            SIMD3<Float>(-0.09, -0.09, 0),
            SIMD3<Float>(-0.000_001, 0, 0),
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0.089_999, 0.09, 0),
            SIMD3<Float>(0.09, 0.18, 0),
            SIMD3<Float>(0.269_999, 0.27, 0),
            SIMD3<Float>(0.27, 0.36, 0)
        ]
        let arguments = (
            planeOrigin: SIMD3<Float>.zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0)
        )

        let inverse = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: centroids,
            planeOrigin: arguments.planeOrigin,
            firstPlaneVector: arguments.firstPlaneVector,
            secondPlaneVector: arguments.secondPlaneVector,
            includeEmptyWindows: false,
            minMeshPoints: 2
        )
        let reference = try SurfaceIntegrityProcessor.computeSlidingWindowGridReference(
            meshCentroids: centroids,
            planeOrigin: arguments.planeOrigin,
            firstPlaneVector: arguments.firstPlaneVector,
            secondPlaneVector: arguments.secondPlaneVector,
            includeEmptyWindows: false,
            minMeshPoints: 2
        )

        XCTAssertEqual(inverse.gridIndices, reference.gridIndices)
        XCTAssertEqual(inverse.gridBounds, reference.gridBounds)
        XCTAssertEqual(inverse.windowToMeshIndices, reference.windowToMeshIndices)
        XCTAssertEqual(inverse.membershipCSR, reference.membershipCSR)
    }

    func testInverseSlidingWindowMembershipBenchmarkAgainstReference() throws {
        var state: UInt64 = 0x5EED
        let centroids = (0..<18_323).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let u = Float(state & 0xFFFF) / Float(UInt16.max) * 3.51
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let v = Float(state & 0xFFFF) / Float(UInt16.max) * 2.52
            return SIMD3<Float>(u, v, 0)
        }
        let planeOrigin = SIMD3<Float>.zero
        let firstPlaneVector = SIMD3<Float>(1, 0, 0)
        let secondPlaneVector = SIMD3<Float>(0, 1, 0)

        let inverseStart = ProcessInfo.processInfo.systemUptime
        let inverse = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: centroids,
            planeOrigin: planeOrigin,
            firstPlaneVector: firstPlaneVector,
            secondPlaneVector: secondPlaneVector
        )
        let inverseDuration = ProcessInfo.processInfo.systemUptime - inverseStart

        let referenceStart = ProcessInfo.processInfo.systemUptime
        let reference = try SurfaceIntegrityProcessor.computeSlidingWindowGridReference(
            meshCentroids: centroids,
            planeOrigin: planeOrigin,
            firstPlaneVector: firstPlaneVector,
            secondPlaneVector: secondPlaneVector
        )
        let referenceDuration = ProcessInfo.processInfo.systemUptime - referenceStart

        XCTAssertEqual(inverse.gridIndices, reference.gridIndices)
        XCTAssertEqual(inverse.windowToMeshIndices, reference.windowToMeshIndices)
        XCTAssertEqual(inverse.membershipCSR, reference.membershipCSR)

        let inverseMilliseconds = inverseDuration * 1_000
        let referenceMilliseconds = referenceDuration * 1_000
        let speedup = referenceDuration / max(inverseDuration, .leastNonzeroMagnitude)
        print(
            "[GRID BENCHMARK] inverse_ms=\(inverseMilliseconds) "
                + "reference_ms=\(referenceMilliseconds) speedup=\(speedup) "
                + "polygons=\(centroids.count) windows=\(inverse.gridIndices.count) "
                + "memberships=\(inverse.membershipCSR.membershipCount)"
        )
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

    func testSlidingWindowGridBuildsCenteredPredictionCell() throws {
        let grid = try SurfaceIntegrityProcessor.computeSlidingWindowGrid(
            meshCentroids: [SIMD3<Float>(10, 20, 30)],
            planeOrigin: SIMD3<Float>(10, 20, 30),
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 0, 1),
            cellSize: 0.27,
            stride: 0.09,
            predictionCellSize: 0.09
        )

        XCTAssertEqual(grid.predictionCellSize, 0.09, accuracy: 0.000_001)
        XCTAssertEqual(grid.predictionCellBounds[0].minU, 0.09, accuracy: 0.000_001)
        XCTAssertEqual(grid.predictionCellBounds[0].maxU, 0.18, accuracy: 0.000_001)
        XCTAssertEqual(grid.predictionCellBounds[0].minV, 0.09, accuracy: 0.000_001)
        XCTAssertEqual(grid.predictionCellBounds[0].maxV, 0.18, accuracy: 0.000_001)
        XCTAssertEqual(grid.predictionCellBounds3D[0][0].x, 10.09, accuracy: 0.000_001)
        XCTAssertEqual(grid.predictionCellBounds3D[0][0].z, 30.09, accuracy: 0.000_001)
        XCTAssertEqual(grid.predictionCellBounds3D[0][2].x, 10.18, accuracy: 0.000_001)
        XCTAssertEqual(grid.predictionCellBounds3D[0][2].z, 30.18, accuracy: 0.000_001)
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
        XCTAssertEqual(features[SurfaceIntegrityWindowFeature("normal_deviation_mean")], 5)
        XCTAssertEqual(features[SurfaceIntegrityWindowFeature("normal_deviation_median")], 10.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(features[SurfaceIntegrityWindowFeature("normal_deviation_proportion_above_5")], 0.75)
        XCTAssertEqual(features[SurfaceIntegrityWindowFeature("height_residuals_std")], 2)
        XCTAssertEqual(features[SurfaceIntegrityWindowFeature("height_residuals_absolute_mean")], 2)
        XCTAssertEqual(features[SurfaceIntegrityWindowFeature("signed_tilt_magnitude_mean")], 8.5)
    }

    func testEmptyWindowFeaturesUsePlaceholders() throws {
        let features = try SurfaceIntegrityProcessor.processWindowFeatures(
            surfaceDetails: [],
            heightResiduals: [],
            signedTiltData: [],
            heightFromGround: nil
        )

        XCTAssertEqual(features.values.count, SurfaceIntegrityFeatureConfiguration.pythonModelDefault.allColumns.count)
        for feature in SurfaceIntegrityFeatureConfiguration.pythonModelDefault.allColumns
            where feature != .heightFromGround {
            XCTAssertEqual(features[feature], 0)
        }
        XCTAssertTrue(features[.heightFromGround].isNaN)
    }

    func testWindowFeatureConfigurationGeneratesAndCalculatesSelectedColumns() throws {
        let group = SurfaceIntegrityFeatureGroupConfiguration(
            source: .normalDeviation,
            label: "python_sync_test",
            centralTendencyFeatures: [.mean],
            percentileFeatures: [50],
            tailFeatures: [7.5],
            distributionShapeFeatures: [.entropy]
        )
        let configuration = SurfaceIntegrityFeatureConfiguration(featureGroups: [group])
        let details = [
            MeshSurfaceDetail(
                centroid: .zero,
                normal: SIMD3<Float>(0, 0, 1),
                area: 1,
                angularDeviationDegrees: 5
            ),
            MeshSurfaceDetail(
                centroid: .zero,
                normal: SIMD3<Float>(0, 0, 1),
                area: 3,
                angularDeviationDegrees: 10
            )
        ]

        let features = try SurfaceIntegrityProcessor.processWindowFeatures(
            surfaceDetails: details,
            heightResiduals: [0, 0],
            signedTiltData: [
                SignedTiltData(tiltUDegrees: 0, tiltVDegrees: 0, tiltMagnitudeDegrees: 90),
                SignedTiltData(tiltUDegrees: 0, tiltVDegrees: 0, tiltMagnitudeDegrees: 90)
            ],
            heightFromGround: 1,
            configuration: configuration
        )

        XCTAssertEqual(
            group.columns.map(\.rawValue),
            [
                "python_sync_test_mean",
                "python_sync_test_p50",
                "python_sync_test_proportion_above_7_5",
                "python_sync_test_entropy"
            ]
        )
        XCTAssertEqual(features[SurfaceIntegrityWindowFeature("python_sync_test_mean")], 7.5)
        XCTAssertEqual(features[SurfaceIntegrityWindowFeature("python_sync_test_p50")], 20.0 / 3.0, accuracy: 0.000_001)
        XCTAssertEqual(features[SurfaceIntegrityWindowFeature("python_sync_test_proportion_above_7_5")], 0.75)
        XCTAssertNil(features.values[SurfaceIntegrityWindowFeature("python_sync_test_std")])
        XCTAssertEqual(features.orderedColumns, configuration.allColumns)
    }

    func testMeshWindowAnalysisKeepsFilteredPolygonIndicesAligned() throws {
        let processor = try SurfaceIntegrityProcessor()
        let meshContents = MeshContents(
            positions: [
                packed_float3(x: -1, y: -1, z: 0),
                packed_float3(x: -1, y: -1, z: 0),
                packed_float3(x: -1, y: -1, z: 0),
                packed_float3(x: 0.02, y: 0.02, z: 0),
                packed_float3(x: 0.05, y: 0.02, z: 0),
                packed_float3(x: 0.02, y: 0.05, z: 0),
                packed_float3(x: 0.11, y: 0.02, z: 0),
                packed_float3(x: 0.14, y: 0.02, z: 0),
                packed_float3(x: 0.11, y: 0.05, z: 0)
            ],
            indices: Array(0...8).map(UInt32.init),
            colorR8: 255,
            colorG8: 255,
            colorB8: 255
        )

        let result = try processor.analyzeMeshWindows(
            meshPolygons: meshContents.polygons,
            planeOrigin: .zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            planeNormal: SIMD3<Float>(0, 0, 1),
            damagePolygonsOnPlane: [
                rectangle(minX: 0, minY: 0, maxX: 0.27, maxY: 0.27)
            ],
            damageConfidenceScores: [0.8],
            heightFromGround: 1.5
        )

        XCTAssertEqual(result.windows.count, 2)
        XCTAssertEqual(result.windows[0].gridIndex, SIMD2<Int32>(0, 0))
        XCTAssertEqual(result.windows[0].surfaceDetailIndices, [0, 1])
        XCTAssertEqual(result.windows[1].surfaceDetailIndices, [1])
        XCTAssertEqual(result.windows[0].features[.numberOfPolygons], 2)
        XCTAssertEqual(result.windows[1].features[.numberOfPolygons], 1)
        XCTAssertEqual(result.windows[0].features[.heightFromGround], 1.5)
        XCTAssertEqual(result.windows[0].damageOverlapRatio, 1, accuracy: 0.000_001)
        XCTAssertEqual(result.windows[0].maximumDamageConfidence, 0.8, accuracy: 0.000_001)
        XCTAssertTrue(result.windows[0].hasSurfaceDisruption)
    }

    func testMeshWindowAnalysisRequiresDamageOverlapAboveQuarter() throws {
        let processor = try SurfaceIntegrityProcessor()
        let predictionModel = SurfaceIntegrityLogisticRegression(
            identifier: "quarter-overlap-test",
            schemaVersion: 1,
            terms: [.init(
                feature: .damageOverlapRatio,
                coefficient: 1,
                mean: 0.25,
                scale: 1,
                missingValue: 0
            )],
            intercept: 0,
            classificationThreshold: 0.500_000_1
        )
        let meshContents = MeshContents(
            positions: [
                packed_float3(x: 0.02, y: 0.02, z: 0),
                packed_float3(x: 0.05, y: 0.02, z: 0),
                packed_float3(x: 0.02, y: 0.05, z: 0)
            ],
            indices: [0, 1, 2],
            colorR8: 255,
            colorG8: 255,
            colorB8: 255
        )
        let commonArguments = (
            planeOrigin: SIMD3<Float>.zero,
            firstPlaneVector: SIMD3<Float>(1, 0, 0),
            secondPlaneVector: SIMD3<Float>(0, 1, 0),
            planeNormal: SIMD3<Float>(0, 0, 1)
        )

        let atThreshold = try processor.analyzeMeshWindows(
            meshPolygons: meshContents.polygons,
            planeOrigin: commonArguments.planeOrigin,
            firstPlaneVector: commonArguments.firstPlaneVector,
            secondPlaneVector: commonArguments.secondPlaneVector,
            planeNormal: commonArguments.planeNormal,
            damagePolygonsOnPlane: [
                rectangle(minX: 0, minY: 0, maxX: 0.0675, maxY: 0.27)
            ],
            damageConfidenceScores: [1],
            heightFromGround: 1,
            predictionModel: predictionModel
        )
        let aboveThreshold = try processor.analyzeMeshWindows(
            meshPolygons: meshContents.polygons,
            planeOrigin: commonArguments.planeOrigin,
            firstPlaneVector: commonArguments.firstPlaneVector,
            secondPlaneVector: commonArguments.secondPlaneVector,
            planeNormal: commonArguments.planeNormal,
            damagePolygonsOnPlane: [
                rectangle(minX: 0, minY: 0, maxX: 0.0676, maxY: 0.27)
            ],
            damageConfidenceScores: [1],
            heightFromGround: 1,
            predictionModel: predictionModel
        )

        XCTAssertEqual(atThreshold.windows[0].damageOverlapRatio, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(atThreshold.windows[0].surfaceDisruptionLogit, 0, accuracy: 0.000_001)
        XCTAssertEqual(atThreshold.windows[0].surfaceDisruptionProbability, 0.5, accuracy: 0.000_001)
        XCTAssertFalse(atThreshold.windows[0].hasSurfaceDisruption)
        XCTAssertTrue(aboveThreshold.windows[0].hasSurfaceDisruption)
    }

    func testUnavailableGPUFeatureResultFailsClosedWithoutPrediction() {
        let features = SurfaceIntegrityProcessor.makeUnavailableWindowFeatures(
            heightFromGround: 1.4,
            configuration: .pythonModelDefault
        )
        let prediction = SurfaceIntegrityProcessor.unavailableSurfaceIntegrityPrediction

        XCTAssertTrue(features.orderedValues.dropLast().allSatisfy { $0 == 0 })
        XCTAssertEqual(features[.heightFromGround], 1.4, accuracy: 0.000_001)
        XCTAssertEqual(prediction.probability, 0)
        XCTAssertFalse(prediction.isDisrupted)
        XCTAssertTrue(prediction.logit.isNaN)
    }

    func testLogisticRegressionAppliesStandardizationAndReturnsProbability() throws {
        let model = SurfaceIntegrityLogisticRegression(
            identifier: "test",
            schemaVersion: 1,
            terms: [
                .init(
                    feature: .damageOverlapRatio,
                    coefficient: 2,
                    mean: 0.2,
                    scale: 0.1,
                    missingValue: 0
                ),
                .init(
                    feature: .maximumDamageConfidence,
                    coefficient: -1,
                    mean: 0.5,
                    scale: 0.25,
                    missingValue: 0
                )
            ],
            intercept: 0.3,
            classificationThreshold: 0.5
        )

        let prediction = try model.predict(features: [
            .damageOverlapRatio: 0.4,
            .maximumDamageConfidence: 0.75
        ])

        XCTAssertEqual(prediction.logit, 3.3, accuracy: 0.000_001)
        XCTAssertEqual(prediction.probability, 1 / (1 + exp(-3.3)), accuracy: 0.000_001)
        XCTAssertTrue(prediction.isDisrupted)
    }

    func testLogisticRegressionUsesConfiguredMissingValue() throws {
        let meshFeature = SurfaceIntegrityModelFeature.windowFeature(
            SurfaceIntegrityWindowFeature("normal_deviation_mean")
        )
        let model = SurfaceIntegrityLogisticRegression(
            identifier: "missing-value-test",
            schemaVersion: 1,
            terms: [
                .init(
                    feature: meshFeature,
                    coefficient: 2,
                    mean: 1,
                    scale: 2,
                    missingValue: 3
                )
            ],
            intercept: 0,
            classificationThreshold: 0.5
        )

        let prediction = try model.predict(features: [:])

        XCTAssertEqual(prediction.logit, 2, accuracy: 0.000_001)
    }

    func testPlaceholderLogisticRegression2MatchesExportedSchema() throws {
        let model = SurfaceIntegrityAnalysisModelZoo.placeholderLogisticRegression2

        try model.validate()
        XCTAssertEqual(model.identifier, "surface-integrity-placeholder-v2")
        XCTAssertEqual(model.schemaVersion, 2)
        XCTAssertEqual(model.intercept, -2.0442088686876745, accuracy: 1e-15)
        XCTAssertEqual(model.classificationThreshold, 0.5)
        XCTAssertEqual(model.terms.count, 37)
        XCTAssertEqual(model.terms.first?.feature, .windowFeature(
            SurfaceIntegrityWindowFeature("normal_deviation_mean")
        ))
        XCTAssertEqual(model.terms.suffix(2).map(\.feature), [
            .damageOverlapRatio,
            .maximumDamageConfidence
        ])
        let selectedFeatures = Set(model.featureSchema)
        XCTAssertFalse(selectedFeatures.contains(.windowFeature(.numberOfPolygons)))
        XCTAssertFalse(selectedFeatures.contains(.windowFeature(.totalSidewalkArea)))
        XCTAssertFalse(selectedFeatures.contains(.windowFeature(.averagePolygonArea)))
        XCTAssertFalse(selectedFeatures.contains(.windowFeature(.polygonDensity)))
        XCTAssertFalse(selectedFeatures.contains(.windowFeature(.heightFromGround)))
    }

    func testPlaceholderSurfaceIntegrityModelDeclaresCompleteSchema() throws {
        let model = SurfaceIntegrityAnalysisModelZoo.placeholderLogisticRegression
        let expectedFeatureCount =
            SurfaceIntegrityFeatureConfiguration.pythonModelDefault.allColumns.count + 2
        let declaredWindowFeatures = model.terms.compactMap { term -> SurfaceIntegrityWindowFeature? in
            guard case .windowFeature(let feature) = term.feature else {
                return nil
            }
            return feature
        }

        try model.validate()
        XCTAssertEqual(model.terms.count, expectedFeatureCount)
        XCTAssertEqual(model.classificationThreshold, 0.5)
        XCTAssertEqual(model.terms.first?.feature, .damageOverlapRatio)
        XCTAssertEqual(model.terms.dropFirst().first?.feature, .maximumDamageConfidence)
        XCTAssertEqual(
            declaredWindowFeatures,
            SurfaceIntegrityFeatureConfiguration.pythonModelDefault.allColumns
        )
        XCTAssertTrue(model.terms.allSatisfy { $0.scale > 0 && $0.missingValue != nil })
    }

    func testSurfaceDisruptionAreaAddsPredictionCenterCells() {
        let area = AttributeEstimationPipeline.surfaceDisruptionArea(
            disruptedWindowCount: 3,
            centerCellSize: 0.09
        )

        XCTAssertEqual(area, 0.0243, accuracy: 0.000_001)
    }

    func testNormalizedDepthPointUsesNativeDepthDimensions() throws {
        let depthPoint = try DepthMapProcessor.depthPoint(
            fromNormalizedPoint: CGPoint(x: 0.5, y: 0.25),
            depthWidth: 256,
            depthHeight: 192
        )

        XCTAssertEqual(depthPoint.x, 128, accuracy: 0.000_001)
        XCTAssertEqual(depthPoint.y, 48, accuracy: 0.000_001)
    }

    func testWindowFeatureParityUsesAbsoluteAndRelativeTolerance() {
        let columns = [SurfaceIntegrityWindowFeature("a"), SurfaceIntegrityWindowFeature("b")]
        let cpu = [SurfaceIntegrityWindowFeatures(values: [columns[0]: 1, columns[1]: 1_000], orderedColumns: columns)]
        let staged = [SurfaceIntegrityWindowFeatures(values: [columns[0]: 1.000_05, columns[1]: 1_000.5], orderedColumns: columns)]
        let summary = SurfaceIntegrityProcessor.compareWindowFeatures(
            cpu: cpu, staged: staged, retainedWindowIndices: [7],
            gpuSupportedColumns: Set(columns), absoluteTolerance: 1e-4, relativeTolerance: 1e-3
        )
        XCTAssertTrue(summary.hasParity)
        XCTAssertEqual(summary.totalMismatchCount, 0)
        XCTAssertEqual(summary.comparedValueCount, 2)
    }

    func testWindowFeatureParityTreatsMatchingNaNAndInfinityCorrectly() {
        let columns = [SurfaceIntegrityWindowFeature("nan"), SurfaceIntegrityWindowFeature("inf")]
        let features = SurfaceIntegrityWindowFeatures(
            values: [columns[0]: .nan, columns[1]: .infinity], orderedColumns: columns
        )
        let summary = SurfaceIntegrityProcessor.compareWindowFeatures(
            cpu: [features], staged: [features], retainedWindowIndices: [0],
            gpuSupportedColumns: Set(columns)
        )
        XCTAssertTrue(summary.hasParity)
    }

    func testWindowFeatureParitySeparatesCategoriesAndLimitsDetails() {
        let gpuColumns = (0..<6).map { SurfaceIntegrityWindowFeature("gpu_\($0)") }
        let cpuOnly = SurfaceIntegrityWindowFeature("cpu")
        let columns = gpuColumns + [cpuOnly]
        let referenceValues = Dictionary(uniqueKeysWithValues: columns.map { ($0, Float(1)) })
        let stagedValues = Dictionary(uniqueKeysWithValues: columns.map { ($0, Float(2)) })
        let reference = [SurfaceIntegrityWindowFeatures(values: referenceValues, orderedColumns: columns)]
        let staged = [SurfaceIntegrityWindowFeatures(values: stagedValues, orderedColumns: columns)]
        let summary = SurfaceIntegrityProcessor.compareWindowFeatures(
            cpu: reference, staged: staged, retainedWindowIndices: [0],
            gpuSupportedColumns: Set(gpuColumns), detailLimit: 5
        )
        XCTAssertEqual(summary.gpuSupportedMismatchCount, 6)
        XCTAssertEqual(summary.cpuOnlyMismatchCount, 1)
        XCTAssertEqual(summary.details.count, 5)
        XCTAssertTrue(summary.details.contains { !$0.isGPUSupported })
    }

    func testGPUWindowFeaturesMatchCPUAboveThreadgroupWidth() throws {
        let count = 300
        let details = (0..<count).map { index in
            MeshSurfaceDetail(
                centroid: SIMD3<Float>(Float(index) * 0.000_01, 0, 0),
                normal: SIMD3<Float>(0, 1, 0),
                area: 0.001 + Float(index % 5) * 0.000_1,
                angularDeviationDegrees: Float(index % 31)
            )
        }
        let residuals = (0..<count).map { Float($0 % 17) * 0.001 - 0.008 }
        let tilts = (0..<count).map {
            SignedTiltData(
                tiltUDegrees: Float($0 % 13),
                tiltVDegrees: -Float($0 % 11),
                tiltMagnitudeDegrees: Float($0 % 7)
            )
        }
        let processor = try SurfaceIntegrityProcessor()
        let gpuMembership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: Array(repeating: .zero, count: count),
            gridOriginU: 0,
            gridOriginV: 0,
            gridShape: SIMD2<Int32>(1, 1)
        )
        let cpuMembership = try processor.materializeSlidingWindowMembershipForCPU(gpuMembership)
            .membershipCSR
        let intermediate = try processor.computeGPUWindowFeatureIntermediate(
            surfaceDetails: details,
            heightResiduals: residuals,
            signedTiltData: tilts,
            membership: gpuMembership
        )
        XCTAssertEqual(intermediate.reductions[0].count, UInt32(count))
        XCTAssertEqual(intermediate.reductions[0].minimum, 0, accuracy: 0.000_001)
        XCTAssertEqual(intermediate.reductions[0].maximum, 30, accuracy: 0.000_001)
        let staged = try processor.processStagedWindowFeatures(
            intermediate: intermediate,
            surfaceDetails: details,
            heightResiduals: residuals,
            signedTiltData: tilts,
            membershipCSR: cpuMembership,
            retainedWindowIndices: [0],
            heightFromGround: 1.2
        )
        let cpu = try SurfaceIntegrityProcessor.processWindowFeatures(
            surfaceDetails: details,
            heightResiduals: residuals,
            signedTiltData: tilts,
            heightFromGround: 1.2
        )
        let summary = SurfaceIntegrityProcessor.compareWindowFeatures(
            cpu: [cpu], staged: staged.features, retainedWindowIndices: [0],
            gpuSupportedColumns: staged.supportedColumns
        )
        let mismatchDescription = summary.details.map {
            "\($0.feature.rawValue): cpu=\($0.cpuValue) gpu=\($0.stagedValue) "
                + "abs=\($0.absoluteError) rel=\($0.relativeError)"
        }
        XCTAssertTrue(summary.hasParity, "Mismatches: \(mismatchDescription)")
    }

    func testGPUWindowCenteredMomentsMatchCPUForNonzeroLowVarianceValues() throws {
        let count = 96
        let details = (0..<count).map { index in
            MeshSurfaceDetail(
                centroid: SIMD3<Float>(Float(index) * 0.000_01, 0, 0),
                normal: SIMD3<Float>(0, 1, 0),
                area: 0.001,
                angularDeviationDegrees: 45 + Float(index % 5) * 0.01
            )
        }
        let residuals = (0..<count).map { 1.25 + Float($0 % 7) * 0.000_1 }
        let tilts = (0..<count).map {
            SignedTiltData(
                tiltUDegrees: 75 + Float($0 % 5) * 0.01,
                tiltVDegrees: -60 + Float($0 % 3) * 0.01,
                tiltMagnitudeDegrees: 15 + Float($0 % 7) * 0.01
            )
        }
        let processor = try SurfaceIntegrityProcessor()
        let gpuMembership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: Array(repeating: .zero, count: count),
            gridOriginU: 0,
            gridOriginV: 0,
            gridShape: SIMD2<Int32>(1, 1)
        )
        let cpuMembership = try processor.materializeSlidingWindowMembershipForCPU(gpuMembership)
            .membershipCSR
        let intermediate = try processor.computeGPUWindowFeatureIntermediate(
            surfaceDetails: details,
            heightResiduals: residuals,
            signedTiltData: tilts,
            membership: gpuMembership
        )
        let staged = try processor.processStagedWindowFeatures(
            intermediate: intermediate,
            surfaceDetails: details,
            heightResiduals: residuals,
            signedTiltData: tilts,
            membershipCSR: cpuMembership,
            retainedWindowIndices: [0],
            heightFromGround: 1.2
        )
        let cpu = try SurfaceIntegrityProcessor.processWindowFeatures(
            surfaceDetails: details,
            heightResiduals: residuals,
            signedTiltData: tilts,
            heightFromGround: 1.2
        )
        let summary = SurfaceIntegrityProcessor.compareWindowFeatures(
            cpu: [cpu], staged: staged.features, retainedWindowIndices: [0],
            gpuSupportedColumns: staged.supportedColumns
        )
        let mismatchDescription = summary.details.map {
            "\($0.feature.rawValue): cpu=\($0.cpuValue) gpu=\($0.stagedValue) "
                + "abs=\($0.absoluteError) rel=\($0.relativeError)"
        }
        XCTAssertTrue(summary.hasParity, "Mismatches: \(mismatchDescription)")
    }

    func testGPUOrderStatisticPlanUsesConfigurationColumnSlots() throws {
        let group = SurfaceIntegrityFeatureGroupConfiguration(
            source: .signedTiltV,
            label: "custom",
            centralTendencyFeatures: [.mean, .median],
            percentileFeatures: [75],
            tailFeatures: [],
            distributionShapeFeatures: []
        )
        let plan = try SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(
            configuration: .init(featureGroups: [group])
        )

        XCTAssertEqual(plan.featureStride, 8)
        XCTAssertEqual(plan.primaryDescriptors.count, 2)
        XCTAssertEqual(plan.primaryDescriptors[0].destinationFeatureSlot, 1)
        XCTAssertEqual(plan.primaryDescriptors[1].destinationFeatureSlot, 2)
        XCTAssertEqual(plan.primaryDescriptors.map(\.percentile), [50, 75])
    }

    func testGPUOrderStatisticPlanCompilesMedianAsPercentile50() throws {
        let group = SurfaceIntegrityFeatureGroupConfiguration(
            source: .normalDeviation,
            centralTendencyFeatures: [.median], percentileFeatures: [],
            tailFeatures: [], distributionShapeFeatures: []
        )
        let plan = try SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(
            configuration: .init(featureGroups: [group])
        )

        XCTAssertEqual(plan.primaryDescriptors.count, 1)
        XCTAssertEqual(plan.primaryDescriptors[0].operation, SurfaceIntegrityOrderStatisticOperation.percentile.rawValue)
        XCTAssertEqual(plan.primaryDescriptors[0].percentile, 50)
    }

    func testGPUOrderStatisticPlanReusesConfiguredMedianForMAD() throws {
        let group = SurfaceIntegrityFeatureGroupConfiguration(
            source: .normalDeviation,
            centralTendencyFeatures: [.median, .medianAbsoluteDeviation],
            percentileFeatures: [], tailFeatures: [], distributionShapeFeatures: []
        )
        let plan = try SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(
            configuration: .init(featureGroups: [group])
        )

        XCTAssertEqual(plan.primaryDescriptors.count, 1)
        XCTAssertEqual(plan.madDescriptors.count, 1)
        XCTAssertEqual(plan.madDescriptors[0].dependencySlot, 0)
        XCTAssertEqual(plan.madDescriptors[0].destinationFeatureSlot, 1)
    }

    func testGPUOrderStatisticPlanCreatesInternalMedianForMADWhenNeeded() throws {
        let group = SurfaceIntegrityFeatureGroupConfiguration(
            source: .heightResidual,
            centralTendencyFeatures: [.medianAbsoluteDeviation],
            percentileFeatures: [], tailFeatures: [], distributionShapeFeatures: []
        )
        let plan = try SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(
            configuration: .init(featureGroups: [group])
        )

        XCTAssertEqual(plan.primaryDescriptors.count, 1)
        XCTAssertEqual(plan.primaryDescriptors[0].destinationFeatureSlot, UInt32.max)
        XCTAssertEqual(plan.madDescriptors[0].dependencySlot, 0)
        XCTAssertEqual(plan.madDescriptors[0].destinationFeatureSlot, 0)
    }

    func testGPUOrderStatisticSharedTypesHaveExpectedLayout() {
        XCTAssertEqual(MemoryLayout<SurfaceIntegrityOrderStatisticDescriptorGPU>.stride, 20)
        XCTAssertEqual(MemoryLayout<SurfaceIntegrityOrderStatisticDescriptorGPU>.alignment, 4)
    }

    func testGPUOrderStatisticPlanRejectsInvalidPercentilesAndSlots() {
        let group = SurfaceIntegrityFeatureGroupConfiguration(
            source: .signedTiltU,
            centralTendencyFeatures: [], percentileFeatures: [-1, 101],
            tailFeatures: [], distributionShapeFeatures: []
        )

        XCTAssertThrowsError(try SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(
            configuration: .init(featureGroups: [group])
        ))
    }

    func testWeightedPercentileBreaksEqualValueTiesByPolygonIndex() {
        let result = SurfaceIntegrityProcessor.weightedPercentile(
            values: [0, 10, 10],
            weights: [1, 100, 1],
            polygonIndices: [0, 2, 1],
            percentile: 2
        )

        XCTAssertEqual(result, 10, accuracy: 0.000_001)
    }

    func testGPUWeightedSelectionMatchesPercentilesZero50_75_90And100() throws {
        let values: [Float] = [-10, 0, 10, 20]
        let details = values.enumerated().map { index, value in
            MeshSurfaceDetail(
                centroid: SIMD3<Float>(Float(index), 0, 0), normal: SIMD3<Float>(0, 1, 0),
                area: 1, angularDeviationDegrees: value
            )
        }
        let configuration = SurfaceIntegrityFeatureConfiguration(featureGroups: [
            .init(
                source: .normalDeviation,
                centralTendencyFeatures: [.median],
                percentileFeatures: [0, 75, 90, 100],
                tailFeatures: [], distributionShapeFeatures: []
            )
        ])
        let processor = try SurfaceIntegrityProcessor()
        let membership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: Array(repeating: .zero, count: values.count),
            gridOriginU: 0, gridOriginV: 0, gridShape: SIMD2<Int32>(1, 1)
        )
        let plan = try SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(
            configuration: configuration
        )

        let result = try processor.computeGPUWeightedSelections(
            surfaceDetails: details,
            heightResiduals: Array(repeating: 0, count: values.count),
            signedTiltData: Array(
                repeating: SignedTiltData(tiltUDegrees: 0, tiltVDegrees: 0, tiltMagnitudeDegrees: 0),
                count: values.count
            ),
            membership: membership,
            plan: plan
        )

        XCTAssertEqual(result.primaryValues.count, 5)
        XCTAssertEqual(result.primaryValues[0], 0, accuracy: 0.000_001)
        XCTAssertEqual(result.primaryValues[1], -10, accuracy: 0.000_001)
        XCTAssertEqual(result.primaryValues[2], 10, accuracy: 0.000_001)
        XCTAssertEqual(result.primaryValues[3], 16, accuracy: 0.000_001)
        XCTAssertEqual(result.primaryValues[4], 20, accuracy: 0.000_001)
    }

    func testGPUWeightedSelectionMatchesDuplicateValuesWithUnequalWeights() throws {
        let result = try gpuNormalDeviationSelections(
            values: [0, 10, 10], weights: [1, 100, 1], percentiles: [2]
        )
        let expected = SurfaceIntegrityProcessor.weightedPercentile(
            values: [0, 10, 10], weights: [1, 100, 1],
            polygonIndices: [0, 1, 2], percentile: 2
        )
        XCTAssertEqual(result[0], expected, accuracy: 0.000_1)
    }

    func testGPUWeightedSelectionMatchesZeroAndVerySmallPositiveWeights() throws {
        let result = try gpuNormalDeviationSelections(
            values: [-5, 1, 9], weights: [0, 0.000_001, 1], percentiles: [0, 50, 100]
        )
        XCTAssertEqual(result[0], -5, accuracy: 0.000_001)
        XCTAssertEqual(result[1], 5, accuracy: 0.000_1)
        XCTAssertEqual(result[2], 9, accuracy: 0.000_001)
    }

    func testGPUWeightedSelectionHandlesMoreThan256Memberships() throws {
        let values = (0..<300).map { Float($0 - 150) }
        let result = try gpuNormalDeviationSelections(
            values: values, weights: Array(repeating: 1, count: values.count),
            percentiles: [50, 90]
        )
        XCTAssertEqual(result[0], -1, accuracy: 0.000_1)
        XCTAssertEqual(result[1], 119, accuracy: 0.000_1)
    }

    func testGPUWeightedSelectionHandlesEmptySingleAndConstantWindows() throws {
        let empty = try gpuNormalDeviationSelections(
            values: [7], weights: [1], percentiles: [50],
            uvCoordinates: [SIMD2<Float>(10, 10)]
        )
        XCTAssertTrue(empty[0].isNaN)
        let single = try gpuNormalDeviationSelections(values: [7], weights: [2], percentiles: [50])
        XCTAssertEqual(single[0], 7, accuracy: 0.000_001)
        let constant = try gpuNormalDeviationSelections(
            values: [4, 4, 4], weights: [1, 2, 3], percentiles: [25, 90]
        )
        XCTAssertEqual(constant, [4, 4])
    }

    func testGPUWeightedSelectionRejectsNegativeWeights() throws {
        XCTAssertThrowsError(try gpuNormalDeviationSelections(
            values: [0, 1], weights: [1, -1], percentiles: [50]
        ))
    }

    func testGPUWeightedSelectionRejectsNonFiniteValuesAndWeights() throws {
        XCTAssertThrowsError(try gpuNormalDeviationSelections(
            values: [0, .infinity], weights: [1, 1], percentiles: [50]
        ))
        XCTAssertThrowsError(try gpuNormalDeviationSelections(
            values: [0, 1], weights: [1, .nan], percentiles: [50]
        ))
    }

    func testGPUMADMatchesCPUWithConfiguredMedianReuse() throws {
        let details = [Float(1), 2, 100].enumerated().map { index, value in
            MeshSurfaceDetail(
                centroid: SIMD3<Float>(Float(index), 0, 0), normal: SIMD3<Float>(0, 1, 0),
                area: 1, angularDeviationDegrees: value
            )
        }
        let configuration = SurfaceIntegrityFeatureConfiguration(featureGroups: [
            .init(
                source: .normalDeviation,
                centralTendencyFeatures: [.median, .medianAbsoluteDeviation],
                percentileFeatures: [], tailFeatures: [], distributionShapeFeatures: []
            )
        ])
        let processor = try SurfaceIntegrityProcessor()
        let membership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: Array(repeating: .zero, count: 3),
            gridOriginU: 0, gridOriginV: 0, gridShape: SIMD2<Int32>(1, 1)
        )
        let result = try processor.computeGPUWeightedSelections(
            surfaceDetails: details, heightResiduals: [0, 0, 0],
            signedTiltData: Array(
                repeating: SignedTiltData(tiltUDegrees: 0, tiltVDegrees: 0, tiltMagnitudeDegrees: 0),
                count: 3
            ),
            membership: membership,
            plan: SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(configuration: configuration)
        )

        XCTAssertEqual(result.primaryValues, [1.5])
        XCTAssertEqual(result.madValues[0], 0.5, accuracy: 0.000_1)
    }

    func testGPUMADMatchesCPUWithInternalMedianDependency() throws {
        let values = (0..<300).map { Float($0 % 11) }
        let details = values.enumerated().map { index, value in
            MeshSurfaceDetail(
                centroid: SIMD3<Float>(Float(index), 0, 0), normal: SIMD3<Float>(0, 1, 0),
                area: Float(index % 3 + 1), angularDeviationDegrees: value
            )
        }
        let configuration = SurfaceIntegrityFeatureConfiguration(featureGroups: [
            .init(
                source: .normalDeviation,
                centralTendencyFeatures: [.medianAbsoluteDeviation],
                percentileFeatures: [], tailFeatures: [], distributionShapeFeatures: []
            )
        ])
        let processor = try SurfaceIntegrityProcessor()
        let membership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: Array(repeating: .zero, count: values.count),
            gridOriginU: 0, gridOriginV: 0, gridShape: SIMD2<Int32>(1, 1)
        )
        let result = try processor.computeGPUWeightedSelections(
            surfaceDetails: details, heightResiduals: Array(repeating: 0, count: values.count),
            signedTiltData: Array(
                repeating: SignedTiltData(tiltUDegrees: 0, tiltVDegrees: 0, tiltMagnitudeDegrees: 0),
                count: values.count
            ), membership: membership,
            plan: SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(configuration: configuration)
        )
        let expected = SurfaceIntegrityProcessor.weightedMedianAbsoluteDeviation(
            values: values, weights: details.map(\.area), polygonIndices: Array(values.indices)
        )
        XCTAssertEqual(result.madValues[0], expected, accuracy: 0.000_1)
    }

    func testGPUMADRejectsInvalidDependencySlot() throws {
        let invalidMAD = SurfaceIntegrityOrderStatisticDescriptorGPU(
            source: 0,
            operation: SurfaceIntegrityOrderStatisticOperation.medianAbsoluteDeviation.rawValue,
            percentile: 50,
            dependencySlot: 99,
            destinationFeatureSlot: 0
        )
        let base = try SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(
            configuration: .init(featureGroups: [
                .init(
                    source: .normalDeviation, centralTendencyFeatures: [.median],
                    percentileFeatures: [], tailFeatures: [], distributionShapeFeatures: []
                )
            ])
        )
        let plan = SurfaceIntegrityGPUOrderStatisticPlan(
            primaryDescriptors: base.primaryDescriptors,
            madDescriptors: [invalidMAD], featureStride: 6
        )
        let details = [MeshSurfaceDetail(
            centroid: .zero, normal: SIMD3<Float>(0, 1, 0), area: 1,
            angularDeviationDegrees: 1
        )]
        let processor = try SurfaceIntegrityProcessor()
        let membership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: [.zero], gridOriginU: 0, gridOriginV: 0,
            gridShape: SIMD2<Int32>(1, 1)
        )
        XCTAssertThrowsError(try processor.computeGPUWeightedSelections(
            surfaceDetails: details, heightResiduals: [0],
            signedTiltData: [SignedTiltData(
                tiltUDegrees: 0, tiltVDegrees: 0, tiltMagnitudeDegrees: 0
            )], membership: membership, plan: plan
        ))
    }

    func testGPUFeatureMatrixMatchesCPUDefaultConfiguration() throws {
        let values: [Float] = [1, 2, 4, 8]
        let details = values.enumerated().map { index, value in
            MeshSurfaceDetail(
                centroid: SIMD3<Float>(Float(index), 0, 0), normal: SIMD3<Float>(0, 1, 0),
                area: Float(index + 1) * 0.001, angularDeviationDegrees: value
            )
        }
        let residuals: [Float] = [-0.02, -0.01, 0.01, 0.03]
        let tilts = values.map {
            SignedTiltData(tiltUDegrees: $0, tiltVDegrees: -$0, tiltMagnitudeDegrees: $0 * 0.5)
        }
        let processor = try SurfaceIntegrityProcessor()
        let membership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: Array(repeating: .zero, count: values.count),
            gridOriginU: 0, gridOriginV: 0, gridShape: SIMD2<Int32>(1, 1)
        )
        let result = try processor.computeCompleteGPUWindowFeatures(
            surfaceDetails: details, heightResiduals: residuals, signedTiltData: tilts,
            membership: membership, retainedWindowIndices: [0], heightFromGround: 1.2
        )
        let cpu = try SurfaceIntegrityProcessor.processWindowFeatures(
            surfaceDetails: details, heightResiduals: residuals, signedTiltData: tilts,
            heightFromGround: 1.2, polygonIndices: Array(values.indices)
        )

        XCTAssertEqual(result.featureStride, cpu.orderedValues.count)
        for (gpu, expected) in zip(result.values, cpu.orderedValues) {
            XCTAssertEqual(gpu, expected, accuracy: max(0.000_1, abs(expected) * 0.001))
        }
    }

    func testGPUFeatureMatrixPreservesEmptyWindowPlaceholders() throws {
        let configuration = SurfaceIntegrityFeatureConfiguration(featureGroups: [
            .init(
                source: .normalDeviation,
                centralTendencyFeatures: [.median, .medianAbsoluteDeviation],
                percentileFeatures: [75],
                tailFeatures: [],
                distributionShapeFeatures: []
            )
        ])
        let details = [MeshSurfaceDetail(
            centroid: .zero,
            normal: SIMD3<Float>(0, 1, 0),
            area: 0.01,
            angularDeviationDegrees: 4
        )]
        let tilts = [SignedTiltData(
            tiltUDegrees: 0,
            tiltVDegrees: 0,
            tiltMagnitudeDegrees: 0
        )]
        let processor = try SurfaceIntegrityProcessor()
        let membership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: [.zero],
            gridOriginU: 0,
            gridOriginV: 0,
            gridShape: SIMD2<Int32>(2, 1)
        )
        let plan = try SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(
            configuration: configuration
        )
        let selection = try processor.computeGPUWeightedSelections(
            surfaceDetails: details,
            heightResiduals: [0],
            signedTiltData: tilts,
            membership: membership,
            plan: plan
        )
        XCTAssertTrue(selection.primaryValues[plan.primaryDescriptors.count].isNaN)
        XCTAssertTrue(selection.madValues[plan.madDescriptors.count].isNaN)

        let result = try processor.computeCompleteGPUWindowFeatures(
            surfaceDetails: details,
            heightResiduals: [0],
            signedTiltData: tilts,
            membership: membership,
            retainedWindowIndices: [0, 1],
            heightFromGround: 1.2,
            configuration: configuration
        )
        let emptyRow = Array(result.values[result.featureStride..<(result.featureStride * 2)])
        let heightIndex = configuration.allColumns.firstIndex(of: .heightFromGround)
        for index in emptyRow.indices where index != heightIndex {
            XCTAssertEqual(emptyRow[index], 0)
        }
        XCTAssertEqual(emptyRow[heightIndex!], 1.2, accuracy: 0.000_001)
    }

    private func rectangle(minX: Float, minY: Float, maxX: Float, maxY: Float) -> [SIMD2<Float>] {
        [
            SIMD2<Float>(minX, minY), SIMD2<Float>(maxX, minY),
            SIMD2<Float>(maxX, maxY), SIMD2<Float>(minX, maxY)
        ]
    }

    private func gpuNormalDeviationSelections(
        values: [Float], weights: [Float], percentiles: [Int],
        uvCoordinates: [SIMD2<Float>]? = nil
    ) throws -> [Float] {
        let details = values.enumerated().map { index, value in
            MeshSurfaceDetail(
                centroid: SIMD3<Float>(Float(index), 0, 0), normal: SIMD3<Float>(0, 1, 0),
                area: weights[index], angularDeviationDegrees: value
            )
        }
        let configuration = SurfaceIntegrityFeatureConfiguration(featureGroups: [
            .init(
                source: .normalDeviation, centralTendencyFeatures: [],
                percentileFeatures: percentiles, tailFeatures: [], distributionShapeFeatures: []
            )
        ])
        let processor = try SurfaceIntegrityProcessor()
        let membership = try processor.computeSlidingWindowMembershipGPU(
            uvCoordinates: uvCoordinates ?? Array(repeating: .zero, count: values.count),
            gridOriginU: 0, gridOriginV: 0, gridShape: SIMD2<Int32>(1, 1)
        )
        return try processor.computeGPUWeightedSelections(
            surfaceDetails: details,
            heightResiduals: Array(repeating: 0, count: values.count),
            signedTiltData: Array(
                repeating: SignedTiltData(tiltUDegrees: 0, tiltVDegrees: 0, tiltMagnitudeDegrees: 0),
                count: values.count
            ),
            membership: membership,
            plan: SurfaceIntegrityProcessor.makeGPUOrderStatisticPlan(configuration: configuration)
        ).primaryValues
    }


}
