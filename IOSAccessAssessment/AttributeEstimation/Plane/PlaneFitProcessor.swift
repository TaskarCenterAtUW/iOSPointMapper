//
//  PlaneFitProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/24/26.
//

import Accelerate
import CoreImage

enum PlaneFitProcessorError: Error, LocalizedError {
    case initializationError(message: String)
    case invalidPointData
    case invalidPlaneData
    
    var errorDescription: String? {
        switch self {
        case .initializationError(let message):
            return "PlaneFit Initialization Error: \(message)"
        case .invalidPointData:
            return "The calculated point data is invalid."
        case .invalidPlaneData:
            return "The calculated plane data is invalid."
        }
    }
}

struct Plane: Sendable, CustomStringConvertible {
    var firstEigenVector: simd_float3
    var secondEigenVector: simd_float3
    var n: simd_float3 // Normal vector
    var d: Float      // Offset from origin
    
    var description: String {
        return "Plane(n: \(n), d: \(d), firstEigenVector: \(firstEigenVector), secondEigenVector: \(secondEigenVector))"
    }
}

struct PlaneFitProcessor {
    private let worldPointsProcessor: WorldPointsProcessor
    
    init() throws {
        self.worldPointsProcessor = try WorldPointsProcessor()
    }
    
    private func fitPlanePCA(worldPoints: [WorldPoint]) throws -> Plane {
        guard worldPoints.count>=3 else {
            throw PlaneFitProcessorError.invalidPointData
        }
        let worldPointMean = worldPoints.reduce(simd_float3(0,0,0), { $0 + $1.p }) / Float(worldPoints.count)
        let centeredWorldPoints = worldPoints.map { $0.p - worldPointMean }
        
        var covarianceMatrix = simd_float3x3(0)
        /// Compute covariance matrix
        for point in centeredWorldPoints {
            let outerProduct = simd_float3x3(rows: [
                simd_float3(point.x * point.x, point.x * point.y, point.x * point.z),
                simd_float3(point.y * point.x, point.y * point.y, point.y * point.z),
                simd_float3(point.z * point.x, point.z * point.y, point.z * point.z)
            ])
            covarianceMatrix += outerProduct
        }
        covarianceMatrix = simd_float3x3(rows: [
            covarianceMatrix[0] / Float(worldPoints.count),
            covarianceMatrix[1] / Float(worldPoints.count),
            covarianceMatrix[2] / Float(worldPoints.count),
        ])
        var a = [
            covarianceMatrix[0][0], covarianceMatrix[0][1], covarianceMatrix[0][2],
            covarianceMatrix[1][0], covarianceMatrix[1][1], covarianceMatrix[1][2],
            covarianceMatrix[2][0], covarianceMatrix[2][1], covarianceMatrix[2][2]
        ]
        var eigenvalues = [Float](repeating: 0, count: 3)
        var jobz: Character = "V" /* 'V' */, uplo: Character = "U" /* 'L' */
        var n = Int32(3), lda = Int32(3), info = Int32(0)
        var lwork: Int32 = 8
        var work = [Float](repeating: 0, count: Int(lwork))
        /// TODO: Deprecated. Replace with newer Accelerate APIs.
        ssyev_(&jobz, &uplo, &n, &a, &lda, &eigenvalues, &work, &lwork, &info)
        
        guard info == 0 else {
            throw PlaneFitProcessorError.invalidPlaneData
        }
        
        /// Eigen values in ascending order
        let firstK = 2
        let firstEigenVector = simd_normalize(simd_float3(a[firstK * 3 + 0], a[firstK * 3 + 1], a[firstK * 3 + 2]))
        let secondK = 1
        let secondEigenVector = simd_normalize(simd_float3(a[secondK * 3 + 0], a[secondK * 3 + 1], a[secondK * 3 + 2]))
        let normalK = 0
        let normalVector = simd_normalize(simd_float3(a[normalK * 3 + 0], a[normalK * 3 + 1], a[normalK * 3 + 2]))
        let d = -simd_dot(normalVector, worldPointMean)
        
        let plane = Plane(
            firstEigenVector: firstEigenVector,
            secondEigenVector: secondEigenVector,
            n: normalVector,
            d: d
        )
        return plane
    }
    
    func fitPlanePCAWithImage(
        segmentationLabelImage: CIImage,
        depthImage: CIImage,
        targetValue: UInt8,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3
    ) throws -> Plane {
        let worldPoints = try self.worldPointsProcessor.getWorldPoints(
            segmentationLabelImage: segmentationLabelImage, depthImage: depthImage,
            targetValue: targetValue, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
        
        let worldPointsCPU = try self.worldPointsProcessor.getWorldPointsCPU(
            segmentationLabelImage: segmentationLabelImage, depthImage: depthImage,
            targetValue: targetValue, cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
        )
        /**
         Find distributional differences between GPU and CPU world points
         */
        let gpuCount = worldPoints.count
        let cpuCount = worldPointsCPU.count
        print("PlaneFitProcessor: GPU World Points Count: \(gpuCount), CPU World Points Count: \(cpuCount)")
        /// Sort by magnitude and do a chi-squared test
        let worldPointsGPUSorted = worldPoints.map { simd_length($0.p) }.sorted()
        let worldPointsCPUSorted = worldPointsCPU.map { simd_length($0.p) }.sorted()
        let minCount = min(gpuCount, cpuCount)
        var chiSum: Float = 0
        for i in 0..<minCount {
            var numerator = (worldPointsGPUSorted[i] - worldPointsCPUSorted[i])
            numerator *= numerator
            let denominator = worldPointsCPUSorted[i] + 1e-6
            chiSum += numerator / denominator
        }
        print("PlaneFitProcessor: Chi-squared sum between GPU and CPU world points: \(chiSum)")
        let df = minCount - 1
        print("PlaneFitProcessor: Degrees of Freedom: \(df)")
        
        return try fitPlanePCA(worldPoints: worldPoints)
    }
}
