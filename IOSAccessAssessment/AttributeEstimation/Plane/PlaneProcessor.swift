//
//  PlaneProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 1/24/26.
//

import Accelerate
import CoreImage

enum PlaneProcessorError: Error, LocalizedError {
    case initializationError(message: String)
    case invalidPointData
    case invalidMeshData
    case invalidPlaneData
    case invalidProjectionData
    
    var errorDescription: String? {
        switch self {
        case .initializationError(let message):
            return "PlaneFit Initialization Error: \(message)"
        case .invalidPointData:
            return "The calculated point data is invalid."
        case .invalidMeshData:
            return "The provided mesh data is invalid."
        case .invalidPlaneData:
            return "The calculated plane data is invalid."
        case .invalidProjectionData:
            return "The projected plane data is invalid."
        }
    }
}

struct Plane: Sendable, CustomStringConvertible {
    var firstVector: simd_float3
    var secondVector: simd_float3
    var normalVector: simd_float3 // Normal vector
    var d: Float      // Offset from origin
    
    var origin: simd_float3
    
    var description: String {
        return "Plane(firstVector: \(firstVector), \nsecondVector: \(secondVector), \nnormalVector: \(normalVector), \nd: \(d), \norigin: \(origin))"
    }
}

struct ProjectedPlane: Sendable, CustomStringConvertible {
    var origin: SIMD2<Float>
    var firstVector: (SIMD2<Float>, SIMD2<Float>)
    var secondVector: (SIMD2<Float>, SIMD2<Float>)
    var normalVector: (SIMD2<Float>, SIMD2<Float>)
    
    /// Can contain reference vectors for debugging or visualization
    var additionalVectors: [(SIMD2<Float>, SIMD2<Float>)]
    
    var description: String {
        return "ProjectedPlane(firstVector: \(firstVector), \nsecondVector: \(secondVector), \nnormalVector: \(normalVector), additionalVectorsCount: \(additionalVectors.count), \norigin: \(origin))"
    }
}

struct PlaneProcessor {
    private let worldPointsProcessor: WorldPointsProcessor
    
    init(worldPointsProcessor: WorldPointsProcessor) {
        self.worldPointsProcessor = worldPointsProcessor
    }
    
    func fitPlanePCA(worldPoints: [WorldPoint]) throws -> Plane {
        guard worldPoints.count>=3 else {
            throw PlaneProcessorError.invalidPointData
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
            throw PlaneProcessorError.invalidPlaneData
        }
        
        /// Eigen values are in ascending order
        let firstK = 2
        let firstEigenVector = simd_normalize(simd_float3(a[firstK * 3 + 0], a[firstK * 3 + 1], a[firstK * 3 + 2]))
        let secondK = 1
        let secondEigenVector = simd_normalize(simd_float3(a[secondK * 3 + 0], a[secondK * 3 + 1], a[secondK * 3 + 2]))
        let normalK = 0
        let normalVector = simd_normalize(simd_float3(a[normalK * 3 + 0], a[normalK * 3 + 1], a[normalK * 3 + 2]))
        let d = -simd_dot(normalVector, worldPointMean)
        
        let plane = Plane(
            firstVector: firstEigenVector,
            secondVector: secondEigenVector,
            normalVector: normalVector,
            d: d,
            origin: worldPointMean
        )
        return plane
    }
    
    func fitPlanePCA(points: [WorldPoint], weights: [Float]? = nil) throws -> Plane {
        guard points.count>=3 else {
            throw PlaneProcessorError.invalidPointData
        }
        var weightsLocal: [Float] = weights ?? [Float](repeating: 1.0, count: points.count)
        if weightsLocal.count != points.count {
            throw PlaneProcessorError.invalidPointData
        }
        
        /// Compute weighted mean
        let W = weightsLocal.reduce(0, +)
        let pointMean = zip(points, weightsLocal).reduce(simd_float3(0,0,0)) { $0 + $1.0.p * $1.1 } / max(W, 1e-6)
        
        /// Compute covariance matrix
        var covarianceMatrix = simd_float3x3(0)
        for (point, weight) in zip(points, weightsLocal) {
            let diff = point.p - pointMean
            let weightedOuterProduct = simd_float3x3(rows: [
                simd_float3(diff.x * diff.x, diff.x * diff.y, diff.x * diff.z) * weight,
                simd_float3(diff.y * diff.x, diff.y * diff.y, diff.y * diff.z) * weight,
                simd_float3(diff.z * diff.x, diff.z * diff.y, diff.z * diff.z) * weight
            ])
        }
        covarianceMatrix = simd_float3x3(rows: [
            covarianceMatrix[0] / Float(points.count),
            covarianceMatrix[1] / Float(points.count),
            covarianceMatrix[2] / Float(points.count),
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
            throw PlaneProcessorError.invalidPlaneData
        }
        
        /// Eigen values are in ascending order
        let firstK = 2
        let firstEigenVector = simd_normalize(simd_float3(a[firstK * 3 + 0], a[firstK * 3 + 1], a[firstK * 3 + 2]))
        let secondK = 1
        let secondEigenVector = simd_normalize(simd_float3(a[secondK * 3 + 0], a[secondK * 3 + 1], a[secondK * 3 + 2]))
        let normalK = 0
        let normalVector = simd_normalize(simd_float3(a[normalK * 3 + 0], a[normalK * 3 + 1], a[normalK * 3 + 2]))
        let d = -simd_dot(normalVector, pointMean)
        
        let plane = Plane(
            firstVector: firstEigenVector,
            secondVector: secondEigenVector,
            normalVector: normalVector,
            d: d,
            origin: pointMean
        )
        return plane
    }
}

/**
 Extension for aligning planes based on camera view direction.
 */
extension PlaneProcessor {
    /**
        Function to align the plane's vectors based on camera view direction.
     
        NOTE:
        The alignment prioritizes making sure that the running vector is aligned sufficiently with the camera view direction in the horizontal plane.
        This is because the app assumes the device is pointed along the running direction.
     */
    func alignPlaneWithViewDirection(
        plane: Plane,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> Plane {
        let alignmentThreshold = Constants.OtherConstants.directionAlignmentDotProductThreshold
        let viewVector = simd_normalize(simd_float3(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        ) * -1)
        let firstVectorAlignment = checkVectorsHorizontalAlignment(
            vector1: plane.firstVector,
            vector2: viewVector
        )
        let secondVectorAlignment = checkVectorsHorizontalAlignment(
            vector1: plane.secondVector,
            vector2: viewVector
        )
        var runningVector: simd_float3
        var crossVector: simd_float3
        /// If neither are aligned, try to align the viewVector to be perpendicular to the plane normal, and use its orthogonal as cross
        if firstVectorAlignment < alignmentThreshold && secondVectorAlignment < alignmentThreshold {
            /// Optionally, use the view's horizontal projection to avoid steep angles
            let up = SIMD3<Float>(0, 1, 0)
            let viewVectorHorizontal = simd_normalize(viewVector - simd_dot(viewVector, up) * up)
            let viewVectorOnPlane = simd_normalize(viewVectorHorizontal - simd_dot(viewVectorHorizontal, plane.normalVector) * plane.normalVector)
            let viewVectorOnPlaneLength = simd_length(viewVectorOnPlane)
            if viewVectorOnPlaneLength < 1e-3 {
                /// View vector nearly aligned with normal, fallback to first vector
                runningVector = simd_normalize(plane.firstVector)
                crossVector = simd_normalize(simd_cross(plane.normalVector, runningVector))
            } else {
                runningVector = viewVectorOnPlane
                crossVector = simd_normalize(simd_cross(plane.normalVector, runningVector))
            }
        }
        /// If first is aligned, use it as running vector and its orthogonal as the cross
        else if firstVectorAlignment >= secondVectorAlignment {
            runningVector = simd_normalize(plane.firstVector)
            crossVector = simd_normalize(simd_cross(plane.normalVector, runningVector))
        }
        /// If second is aligned, use it as running vector and its orthogonal as the cross
        else {
            runningVector = simd_normalize(plane.secondVector)
            crossVector = simd_normalize(simd_cross(plane.normalVector, runningVector))
        }
        let alignedPlane = Plane(
            firstVector: runningVector,
            secondVector: crossVector,
            normalVector: plane.normalVector,
            d: plane.d,
            origin: plane.origin
        )
//        print(plane, "\nCamera Transform: \(cameraTransform), \nView vector: \(viewVector), \n\(alignedPlane)")
        return alignedPlane
    }
    
    private func checkVectorsHorizontalAlignment(
        vector1: simd_float3,
        vector2: simd_float3
    ) -> Float {
        let horizontalVector1 = simd_normalize(simd_float3(vector1.x, 0, vector1.z))
        let horizontalVector2 = simd_normalize(simd_float3(vector2.x, 0, vector2.z))
        let dotProduct = simd_dot(horizontalVector1, horizontalVector2)
//        let angle = acos(dotProduct)
//        let angleDegrees = angle * (180.0 / .pi)
//        let finalAngleDegrees = min(angleDegrees, 180.0 - angleDegrees)
//        print("Angle between projected vectors: \(finalAngleDegrees) degrees")
        return abs(dotProduct)
    }
}

/**
 Extension for projecting planes to 2D pixel coordinates.
 */
extension PlaneProcessor {
    /**
        Function to project a 3D plane to 2D pixel coordinates.
        Can be used for visualization or debugging purposes.
     */
    func projectPlane(
        plane: Plane,
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> ProjectedPlane {
        let viewMatrix = cameraTransform.inverse // world->camera
        guard let projectedOrigin = projectWorldToPixel(
            plane.origin, viewMatrix: viewMatrix, intrinsics: cameraIntrinsics, imageSize: imageSize
        ) else {
            throw PlaneProcessorError.invalidProjectionData
        }
        let vectorsToProject = [plane.firstVector, plane.secondVector, plane.normalVector]
        let projectedVectors: [(SIMD2<Float>, SIMD2<Float>)] = try vectorsToProject.map {
            try getProjectedVector(
                origin: plane.origin,
                vector: $0,
                viewMatrix: viewMatrix,
                cameraIntrinsics: cameraIntrinsics,
                imageSize: imageSize
            )
        }
        /// Additional vectors for reference
        let viewVector = simd_normalize(simd_float3(
            cameraTransform.columns.2.x,
            cameraTransform.columns.2.y,
            cameraTransform.columns.2.z
        ) * -1)
        let additionalVectors: [(SIMD2<Float>, SIMD2<Float>)] = try [
            viewVector
        ].map {
            try getProjectedVector(
                origin: plane.origin,
                vector: $0,
                viewMatrix: viewMatrix,
                cameraIntrinsics: cameraIntrinsics,
                imageSize: imageSize
            )
        }
        return ProjectedPlane(
            origin: projectedOrigin,
            firstVector: projectedVectors[0],
            secondVector: projectedVectors[1],
            normalVector: projectedVectors[2],
            additionalVectors: additionalVectors
        )
    }
    
    /**
        Function to project a 3D vector originating from a 3D point to 2D pixel coordinates.
     
        Ensures that the projected points are valid and within the image bounds by returning points at the corners of the image
     
        NOTE: lengthThreshold is in pixel space.
     */
    private func getProjectedVector(
        origin: simd_float3,
        vector: simd_float3,
        viewMatrix: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize,
        lengthThreshold: Float = 500.0
    ) throws -> (SIMD2<Float>, SIMD2<Float>) {
        /// First, project the two endpoints of the vector
        let points = [origin, origin + vector, origin - vector]
        let projectedPoints: [SIMD2<Float>] = points.map {
            projectWorldToPixel($0, viewMatrix: viewMatrix, intrinsics: cameraIntrinsics, imageSize: imageSize)
        }.compactMap { $0 }
        guard let p1 = projectedPoints.first,
              let p2 = projectedPoints.last else {
            throw PlaneProcessorError.invalidProjectionData
        }
        /// Second, express the vector as a line equation: L(s) = p1 + s * (p2 - p1)
        let startPoint = p1
        let delta = p2 - p1
        /// Third, find intersections with image bounds
        var candidates: [SIMD2<Float>] = []
        /// Intersect with X=0
        if delta.x != 0 {
            let s = -startPoint.x / delta.x
            let y = startPoint.y + s * delta.y
            if y >= 0 && y < Float(imageSize.height) {
                let intersectionPoint = SIMD2<Float>(0, y)
                candidates.append(intersectionPoint)
            }
        }
        /// Intersect with X=width-1
        if delta.x != 0 {
            let s = (Float(imageSize.width) - 1 - startPoint.x) / delta.x
            let y = startPoint.y + s * delta.y
            if y >= 0 && y < Float(imageSize.height) {
                let intersectionPoint = SIMD2<Float>(Float(imageSize.width) - 1, y)
                candidates.append(intersectionPoint)
            }
        }
        /// Intersect with Y=0
        if delta.y != 0 {
            let s = -startPoint.y / delta.y
            let x = startPoint.x + s * delta.x
            if x >= 0 && x < Float(imageSize.width) {
                let intersectionPoint = SIMD2<Float>(x, 0)
                candidates.append(intersectionPoint)
            }
        }
        /// Intersect with Y=height-1
        if delta.y != 0 {
            let s = (Float(imageSize.height) - 1 - startPoint.y) / delta.y
            let x = startPoint.x + s * delta.x
            if x >= 0 && x < Float(imageSize.width) {
                let intersectionPoint = SIMD2<Float>(x, Float(imageSize.height) - 1)
                candidates.append(intersectionPoint)
            }
        }
        guard let firstProjectedPoint = candidates.first,
              let secondProjectedPoint = candidates.last else {
            throw PlaneProcessorError.invalidProjectionData
        }
        /// If length is more than length threshold, truncate to the threshold length
        if getPixelDistance(firstProjectedPoint, secondProjectedPoint) < lengthThreshold {
            return (firstProjectedPoint, secondProjectedPoint)
        }
        let direction = simd_normalize(secondProjectedPoint - firstProjectedPoint)
        let midpoint = (firstProjectedPoint + secondProjectedPoint) / 2
        let truncatedFirstPoint = midpoint - direction * lengthThreshold / 2
        let truncatedSecondPoint = midpoint + direction * lengthThreshold / 2
        return (truncatedFirstPoint, truncatedSecondPoint)
//        return (firstProjectedPoint, secondProjectedPoint)
    }
    
    /**
        Function to project a 3D world point to 2D pixel coordinates.
     
        Returns coordinates even if they are outside the image bounds.
     */
    private func projectWorldToPixel(
        _ world: simd_float3,
        viewMatrix: simd_float4x4, // (world->camera)
        intrinsics K: simd_float3x3,
        imageSize: CGSize
    ) -> SIMD2<Float>? {
        let p4   = simd_float4(world, 1.0)
        let pc   = viewMatrix * p4                                  // camera space
        let x = pc.x, y = pc.y, z = pc.z
        
        guard z < 0 else {
            return nil
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
        return SIMD2<Float>(u.rounded(), v.rounded())
    }
    
    private func getPixelDistance(_ p1: SIMD2<Float>, _ p2: SIMD2<Float>) -> Float {
        return simd_length(p1 - p2)
    }
}
