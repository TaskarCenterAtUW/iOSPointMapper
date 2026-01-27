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
    case invalidProjectionData
    
    var errorDescription: String? {
        switch self {
        case .initializationError(let message):
            return "PlaneFit Initialization Error: \(message)"
        case .invalidPointData:
            return "The calculated point data is invalid."
        case .invalidPlaneData:
            return "The calculated plane data is invalid."
        case .invalidProjectionData:
            return "The projected plane data is invalid."
        }
    }
}

struct Plane: Sendable, CustomStringConvertible {
    var firstEigenVector: simd_float3
    var secondEigenVector: simd_float3
    var n: simd_float3 // Normal vector
    var d: Float      // Offset from origin
    
    var origin: simd_float3
    
    var description: String {
        return "Plane(n: \(n), d: \(d), firstEigenVector: \(firstEigenVector), secondEigenVector: \(secondEigenVector)), origin: \(origin))"
    }
}

struct ProjectedPlane: Sendable, CustomStringConvertible {
    var origin: CGPoint
    var firstEigenVector: (CGPoint, CGPoint)
    var secondEigenVector: (CGPoint, CGPoint)
    var normalVector: (CGPoint, CGPoint)
    
    var description: String {
        return "ProjectedPlane(origin: \(origin), firstEigenVector: \(firstEigenVector), secondEigenVector: \(secondEigenVector), normalVector: \(normalVector))"
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
            d: d,
            origin: worldPointMean
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
        let plane = try fitPlanePCA(worldPoints: worldPoints)
        return plane
    }
    
    func projectPlane(
        plane: Plane,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> ProjectedPlane {
        let viewMatrix = cameraTransform.inverse // world->camera
        let pointsToProject = [
            plane.origin,
            plane.origin + plane.firstEigenVector,
            plane.origin + plane.secondEigenVector,
            plane.origin + plane.n
        ]
        var projectedPoints: [SIMD2<Float>] = try pointsToProject.map {
            try projectWorldToPixel(
                $0,
                viewMatrix: viewMatrix,
                intrinsics: cameraIntrinsics,
                imageSize: imageSize
            )
        }
        let origin2D = CGPoint(x: CGFloat(projectedPoints[0].x), y: CGFloat(projectedPoints[0].y))
        let firstEigenVector2D = ( origin2D, CGPoint(x: CGFloat(projectedPoints[1].x), y: CGFloat(projectedPoints[1].y)) )
        let secondEigenVector2D = ( origin2D, CGPoint(x: CGFloat(projectedPoints[2].x), y: CGFloat(projectedPoints[2].y)) )
        let normalVector2D = ( origin2D, CGPoint(x: CGFloat(projectedPoints[3].x), y: CGFloat(projectedPoints[3].y)) )
        
        return ProjectedPlane(
            origin: origin2D,
            firstEigenVector: firstEigenVector2D,
            secondEigenVector: secondEigenVector2D,
            normalVector: normalVector2D
        )
    }
    
    private func projectWorldToPixel(
        _ world: simd_float3,
        viewMatrix: simd_float4x4, // (world->camera)
        intrinsics K: simd_float3x3,
        imageSize: CGSize
    ) throws -> SIMD2<Float> {
       let p4   = simd_float4(world, 1.0)
       let pc   = viewMatrix * p4                                  // camera space
       let x = pc.x, y = pc.y, z = pc.z
       
       guard z < 0 else {
           throw PlaneFitProcessorError.invalidProjectionData
       }                       // behind camera
       
       // normalized image plane coords (flip Y so +Y goes up in pixels)
       let xn = x / -z
       let yn = -y / -z
       
       // intrinsics (column-major)
       let fx = K.columns.0.x
       let fy = K.columns.1.y
       let cx = K.columns.2.x
       let cy = K.columns.2.y
       
       // pixels in sensor/native image coordinates
       let u = fx * xn + cx
       let v = fy * yn + cy
       
       if u.isFinite && v.isFinite &&
           u >= 0 && v >= 0 &&
           u < Float(imageSize.width) && v < Float(imageSize.height) {
           return SIMD2<Float>(u.rounded(), v.rounded())
       }
        throw PlaneFitProcessorError.invalidProjectionData
   }
}
