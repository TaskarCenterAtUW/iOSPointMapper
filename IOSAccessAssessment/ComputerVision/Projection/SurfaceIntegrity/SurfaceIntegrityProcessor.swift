//
//  SurfaceIntegrityProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 4/9/26.
//

import ARKit
import RealityKit
import MetalKit
import simd

enum SurfaceIntegrityProcessorError: Error, LocalizedError {
    case metalInitializationFailed
    case metalPipelineCreationError
    case metalPipelineBlitEncoderError
    case invalidProjectedPlaneVectors
    case unableToProcessBufferData
    
    var errorDescription: String? {
        switch self {
        case .metalInitializationFailed:
            return "Failed to initialize Metal resources."
        case .metalPipelineCreationError:
            return "Failed to create Metal compute pipeline."
        case .metalPipelineBlitEncoderError:
            return "Failed to create Blit Command Encoder for the Surface Integrity Processor."
        case .invalidProjectedPlaneVectors:
            return "Invalid projected plane vectors."
        case .unableToProcessBufferData:
            return "Unable to process buffer data for surface integrity grid."
        }
    }
}

enum IntegrityStatus: CaseIterable, Identifiable, CustomStringConvertible {
    var id: Self { self }
    
    case intact
    case compromised
    
    var description: String {
        switch self {
        case .intact:
            return "The surface is intact."
        case .compromised:
            return "The surface has integrity issues."
        }
    }
}

struct IntegrityStatusDetails {
    var status: IntegrityStatus
    var details: String
    
    init(status: IntegrityStatus = .intact, details: String = "") {
        self.status = status
        self.details = details
    }
}

struct IntegrityResults {
    var surfaceNormalStatusDetails: IntegrityStatusDetails = IntegrityStatusDetails()
    var boundingBoxAreaStatusDetails: IntegrityStatusDetails = IntegrityStatusDetails()
    var boundingBoxSurfaceNormalStatusDetails: IntegrityStatusDetails = IntegrityStatusDetails()
}

struct SurfaceIntegrityProcessor {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let deviantPipeline: MTLComputePipelineState
    let textureLoader: MTKTextureLoader
    
    let ciContext: CIContext
    
    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else  {
            throw SurfaceIntegrityProcessorError.metalInitializationFailed
        }
        self.device = device
        self.commandQueue = commandQueue
        self.textureLoader = MTKTextureLoader(device: device)
        
        self.ciContext = CIContext(mtlDevice: device, options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
        
        guard let deviantKernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "<>"),
              let deviantPipeline = try? device.makeComputePipelineState(function: deviantKernelFunction) else {
            throw SurfaceIntegrityProcessorError.metalInitializationFailed
        }
        self.deviantPipeline = deviantPipeline
    }
    
    /**
     CPU implementation for surface integrity assessment. Used for benchmarking and fallback when Metal processing is not available.
     */
    func getIntegrityResultsFromImageCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol)
    ) throws -> IntegrityResults {
        let surfaceNormalIntegrityResult = try getSurfaceNormalIntegrityResultFromImageCPU(
            worldPointsGrid: worldPointsGrid,
            plane: plane,
            surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
            damageDetectionResults: damageDetectionResults,
            captureData: captureData
        )
        let boundingBoxAreaIntegrityResult = try getBoundingBoxAreaIntegrityResultFromImageCPU(
            worldPointsGrid: worldPointsGrid,
            plane: plane,
            surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
            damageDetectionResults: damageDetectionResults,
            captureData: captureData
        )
        let boundingBoxSurfaceNormalIntegrityResult = try getBoundingBoxSurfaceNormalIntegrityResultFromImageCPU(
            worldPointsGrid: worldPointsGrid,
            plane: plane,
            surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
            damageDetectionResults: damageDetectionResults,
            captureData: captureData
        )
        return IntegrityResults(
            surfaceNormalStatusDetails: surfaceNormalIntegrityResult,
            boundingBoxAreaStatusDetails: boundingBoxAreaIntegrityResult,
            boundingBoxSurfaceNormalStatusDetails: boundingBoxSurfaceNormalIntegrityResult
        )
    }
    
    /**
        This function assesses the integrity of the surface based on the angular deviation of surface normals from the plane normal. It calculates the proportion of points that deviate beyond a specified angular threshold and determines the integrity status based on whether this proportion exceeds a defined threshold.
     */
    func getSurfaceNormalIntegrityResultFromImageCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol),
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.imagePlaneAngularDeviationThreshold,
        deviantPointProportionThreshold: Float = Constants.SurfaceIntegrityConstants.imageDeviantPointProportionThreshold
    ) throws -> IntegrityStatusDetails {
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        let surfaceNormalDetails = getSurfaceNormalDeviationDetailsWithinBoundsCPU(
            worldPointsGrid: worldPointsGrid,
            plane: plane,
            surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
            bounds: BoundsParams(minX: 0, minY: 0, maxX: Float(width - 1), maxY: Float(height - 1)),
            angularDeviationThreshold: angularDeviationThreshold
        )
        let totalDeviantPoints = surfaceNormalDetails.deviantPointCount
        let totalPoints = surfaceNormalDetails.totalPointCount
        
        let deviantPointProportion = totalPoints > 0 ? Float(totalDeviantPoints) / Float(totalPoints) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantPointProportion > deviantPointProportionThreshold ? .compromised : .intact,
            details: "Deviant Point Proportion: \(deviantPointProportion * 100)%, Total Deviant Points: \(totalDeviantPoints), Total Points: \(totalPoints)"
        )
        return statusDetails
    }
    
    /**
        This function assesses the integrity of the surface based on the area of the bounding box of detected damage. It retrieves world points corresponding to the corners of the bounding box, calculates the area formed by these points, and determines the integrity status based on whether this area exceeds a defined threshold.
     
        - Warning:
        The current implementation assumes a simple rectangular area calculation based on the corners of the bounding box, which may not be accurate due to perspective distortion. A more robust approach would involve calculating the actual surface area on the plane corresponding to the bounding box, potentially using a mesh representation of the surface.
        Need to take into account the UI orientation to decide which parallel lines to use for area calculation.
     */
    func getBoundingBoxAreaIntegrityResultFromImageCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol),
        boundingBoxAreaThreshold: Float = Constants.SurfaceIntegrityConstants.imageBoundingBoxAreaThreshold,
        boundingBoxWorldPointRetrievalRadius: Float = 3.0
    ) throws -> IntegrityStatusDetails {
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        
        func getWorldPointForCGPointWithinRadius(point: CGPoint, radius: Float) -> simd_float3? {
            let x = Int(point.x)
            let y = Int(point.y)
            var pointSum = simd_float3(0, 0, 0)
            var validPointCount = 0
            for offsetY in -Int(radius)...Int(radius) {
                for offsetX in -Int(radius)...Int(radius) {
                    let neighborX = x + offsetX
                    let neighborY = y + offsetY
                    guard neighborX >= 0, neighborX < width, neighborY >= 0, neighborY < height else { continue }
                    let worldPointForNeighbor = worldPointsGrid[neighborX, neighborY]
                    if worldPointForNeighbor.isValid == 1 {
                        pointSum += worldPointForNeighbor.worldPoint.p
                        validPointCount += 1
                    }
                }
            }
            if validPointCount == 0 { return nil }
            return pointSum / Float(validPointCount)
        }
        
        func getWorldPointForPixel(x: Int, y: Int) -> simd_float3? {
            guard x >= 0, x < width, y >= 0, y < height else { return nil }
            let worldPointForPixel = worldPointsGrid[x, y]
            return worldPointForPixel.isValid == 1 ? worldPointForPixel.worldPoint.p : nil
        }
        
        /// Get 2 sets of parallel lines and calculate 2 areas and average them to get a more robust area estimation
        /// TODO: The bounding box is more like a trapezoid due to the perspective, but because the orientation of parallel lines is UI orientation-dependent,
        /// we will go with the current approach for simplicity.
        func getBoundingBoxArea(worldPoints: [simd_float3]) -> Float {
            guard worldPoints.count == 4 else { return 0 }
            let xVector1 = worldPoints[1] - worldPoints[0]
            let yVector1 = worldPoints[3] - worldPoints[0]
            let area1 = simd_length(simd_cross(xVector1, yVector1))
            let xVector2 = worldPoints[2] - worldPoints[1]
            let yVector2 = worldPoints[0] - worldPoints[1]
            let area2 = simd_length(simd_cross(xVector2, yVector2))
            return (area1 + area2) / 2.0
        }
        
        var totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        for damageDetectionResult in damageDetectionResults {
            let boundingBoxParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let boudingBoxPoints: [CGPoint] = [
                CGPoint(x: CGFloat(boundingBoxParams.minX), y: CGFloat(boundingBoxParams.minY)),
                CGPoint(x: CGFloat(boundingBoxParams.maxX), y: CGFloat(boundingBoxParams.minY)),
                CGPoint(x: CGFloat(boundingBoxParams.maxX), y: CGFloat(boundingBoxParams.maxY)),
                CGPoint(x: CGFloat(boundingBoxParams.minX), y: CGFloat(boundingBoxParams.maxY))
            ]
            var boundingBoxWorldPoints: [simd_float3] = boudingBoxPoints.compactMap {
                getWorldPointForCGPointWithinRadius(point: $0, radius: boundingBoxWorldPointRetrievalRadius)
            }
            if boundingBoxWorldPoints.count < 4 { continue }
            if getBoundingBoxArea(worldPoints: boundingBoxWorldPoints) < boundingBoxAreaThreshold { continue }
            deviantBoundingBoxes += 1
            boundingBoxDetails += "Bounding Box with label \(damageDetectionResult.label) and confidence \(damageDetectionResult.confidence) has area above threshold. Area: \(getBoundingBoxArea(worldPoints: boundingBoxWorldPoints)).\n"
        }
        let deviantBoundingBoxProportion = totalBoundingBoxes > 0 ? Float(deviantBoundingBoxes) / Float(totalBoundingBoxes) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantBoundingBoxProportion > 0 ? .compromised : .intact,
            details: "Deviant Bounding Box Proportion: \(deviantBoundingBoxProportion * 100)%, Total Bounding Boxes: \(totalBoundingBoxes), Deviant Bounding Boxes: \(deviantBoundingBoxes). Details: \(boundingBoxDetails)"
        )
        return statusDetails
    }
    
    func getBoundingBoxSurfaceNormalIntegrityResultFromImageCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol),
        boundingBoxAngularStdThreshold: Float = Constants.SurfaceIntegrityConstants.imageBoundingBoxAngularStdThreshold
    ) throws -> IntegrityStatusDetails {
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        
        var totalBoundingBoxes = damageDetectionResults.count
        var deviantBoundingBoxes = 0
        var boundingBoxDetails = ""
        for damageDetectionResult in damageDetectionResults {
            let boundsParams = damageDetectionResult.getBoundsParams(for: captureData.originalSize)
            let angularStd = getSurfaceNormalStdDetailsWithinBoundsCPU(
                worldPointsGrid: worldPointsGrid,
                plane: plane,
                surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
                bounds: boundsParams
            )
            if angularStd > boundingBoxAngularStdThreshold {
                deviantBoundingBoxes += 1
                boundingBoxDetails += "Bounding Box with label \(damageDetectionResult.label) and confidence \(damageDetectionResult.confidence) has surface normal angular std above threshold. Angular Std: \(angularStd).\n"
            }
        }
        let deviantBoundingBoxProportion = totalBoundingBoxes > 0 ? Float(deviantBoundingBoxes) / Float(totalBoundingBoxes) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantBoundingBoxProportion > 0 ? .compromised : .intact,
            details: "Deviant Bounding Box Proportion: \(deviantBoundingBoxProportion * 100)%, Total Bounding Boxes: \(totalBoundingBoxes), Deviant Bounding Boxes: \(deviantBoundingBoxes). Details: \(boundingBoxDetails)"
        )
        return statusDetails
    }
    
    private func getSurfaceNormalDeviationDetailsWithinBoundsCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        bounds: BoundsParams,
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.imagePlaneAngularDeviationThreshold
    ) -> (deviantPointCount: Int, totalPointCount: Int) {
        let planeNormal = plane.normalVector
        var totalDeviantPoints = 0
        var totalPoints = 0
        for y in Int(bounds.minY)...Int(bounds.maxY) {
            for x in Int(bounds.minX)...Int(bounds.maxX) {
                let surfaceNormalForPointGridCell = surfaceNormalsForPointsGrid[x, y]
                if surfaceNormalForPointGridCell.isValid == 0 { continue }
                let surfaceNormal = surfaceNormalForPointGridCell.surfaceNormal
                let angularDeviation = getAngularDeviation(planeNormal, surfaceNormal)
                if angularDeviation > angularDeviationThreshold {
                    totalDeviantPoints += 1
                }
                totalPoints += 1
            }
        }
        return (deviantPointCount: totalDeviantPoints, totalPointCount: totalPoints)
    }
    
    private func getSurfaceNormalStdDetailsWithinBoundsCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        bounds: BoundsParams
    ) -> Float {
        let planeNormal = plane.normalVector
        var angularDeviationSum: Float = 0
        var angularDeviationSquaredSum: Float = 0
        var totalPoints = 0
        for y in Int(bounds.minY)...Int(bounds.maxY) {
            for x in Int(bounds.minX)...Int(bounds.maxX) {
                let surfaceNormalForPointGridCell = surfaceNormalsForPointsGrid[x, y]
                if surfaceNormalForPointGridCell.isValid == 0 { continue }
                let surfaceNormal = surfaceNormalForPointGridCell.surfaceNormal
                let angularDeviation = getAngularDeviation(planeNormal, surfaceNormal)
                angularDeviationSum += angularDeviation
                angularDeviationSquaredSum += angularDeviation * angularDeviation
                totalPoints += 1
            }
        }
        guard totalPoints > 0 else { return 0 }
        let angularDeviationMean = angularDeviationSum / Float(totalPoints)
        let angularDeviationVariance = (angularDeviationSquaredSum / Float(totalPoints)) - (angularDeviationMean * angularDeviationMean)
        let angularDeviationStd = sqrt(angularDeviationVariance)
        return angularDeviationStd
    }
    
    /**
     Get angular deviation between normalized vectors v1 and v2 in degrees.
     */
    private func getAngularDeviation(_ nv1: simd_float3, _ nv2: simd_float3) -> Float {
        let dotProduct = simd_dot(nv1, nv2)
        let angleInRadians = acos(dotProduct)
        let angleInDegrees = angleInRadians * (180.0 / .pi)
        return angleInDegrees
    }
}
