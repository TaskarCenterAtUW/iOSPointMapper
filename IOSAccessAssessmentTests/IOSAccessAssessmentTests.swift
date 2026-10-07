//
//  IOSAccessAssessmentTests.swift
//  IOSAccessAssessmentTests
//
//  Created by Sai on 1/24/24.
//

import XCTest
@testable import IOSAccessAssessment
import PointNMapShared
import PointNMapShaderTypes

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

        let result = try SurfaceIntegrityProcessor.analyzeMeshWindows(
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

        let atThreshold = try SurfaceIntegrityProcessor.analyzeMeshWindows(
            meshPolygons: meshContents.polygons,
            planeOrigin: commonArguments.planeOrigin,
            firstPlaneVector: commonArguments.firstPlaneVector,
            secondPlaneVector: commonArguments.secondPlaneVector,
            planeNormal: commonArguments.planeNormal,
            damagePolygonsOnPlane: [
                rectangle(minX: 0, minY: 0, maxX: 0.0675, maxY: 0.27)
            ],
            damageConfidenceScores: [1],
            heightFromGround: 1
        )
        let aboveThreshold = try SurfaceIntegrityProcessor.analyzeMeshWindows(
            meshPolygons: meshContents.polygons,
            planeOrigin: commonArguments.planeOrigin,
            firstPlaneVector: commonArguments.firstPlaneVector,
            secondPlaneVector: commonArguments.secondPlaneVector,
            planeNormal: commonArguments.planeNormal,
            damagePolygonsOnPlane: [
                rectangle(minX: 0, minY: 0, maxX: 0.0676, maxY: 0.27)
            ],
            damageConfidenceScores: [1],
            heightFromGround: 1
        )

        XCTAssertEqual(atThreshold.windows[0].damageOverlapRatio, 0.25, accuracy: 0.000_001)
        XCTAssertFalse(atThreshold.windows[0].hasSurfaceDisruption)
        XCTAssertTrue(aboveThreshold.windows[0].hasSurfaceDisruption)
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

    private func rectangle(minX: Float, minY: Float, maxX: Float, maxY: Float) -> [SIMD2<Float>] {
        [
            SIMD2<Float>(minX, minY), SIMD2<Float>(maxX, minY),
            SIMD2<Float>(maxX, maxY), SIMD2<Float>(minX, maxY)
        ]
    }


}
