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
    
    func getIntegrityResultsFromImageCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize
    ) throws -> IntegrityResults {
        let damageDetectionBounds: [BoundsParams] = damageDetectionResults.map { $0.getBoundsParams(for: imageSize) }
        let surfaceNormalIntegrityResult = try getSurfaceNormalIntegrityResultFromImageCPU(
            worldPointsGrid: worldPointsGrid,
            plane: plane,
            surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
            damageDetectionResults: damageDetectionResults,
            cameraTransform: cameraTransform,
            cameraIntrinsics: cameraIntrinsics,
            imageSize: imageSize
        )
        return IntegrityResults(
            surfaceNormalStatusDetails: surfaceNormalIntegrityResult,
            boundingBoxAreaStatusDetails: IntegrityStatusDetails(),
            boundingBoxSurfaceNormalStatusDetails: IntegrityStatusDetails()
        )
    }
    
    func getSurfaceNormalIntegrityResultFromImageCPU(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        cameraTransform: simd_float4x4,
        cameraIntrinsics: simd_float3x3,
        imageSize: CGSize,
        angularDeviationThreshold: Float = Constants.SurfaceIntegrityConstants.imagePlaneAngularDeviationThreshold,
        deviantPointProportionThreshold: Float = Constants.SurfaceIntegrityConstants.imageDeviantPointProportionThreshold
    ) throws -> IntegrityStatusDetails {
        let width = surfaceNormalsForPointsGrid.width
        let height = surfaceNormalsForPointsGrid.height
        
        let planeNormal = plane.normalVector
        var totalDeviantPoints = 0
        var totalPoints = 0
        for y in 0..<height {
            for x in 0..<width {
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
        let deviantPointProportion = totalPoints > 0 ? Float(totalDeviantPoints) / Float(totalPoints) : 0
        let statusDetails: IntegrityStatusDetails = IntegrityStatusDetails(
            status: deviantPointProportion > deviantPointProportionThreshold ? .compromised : .intact,
            details: "Deviant Point Proportion: \(deviantPointProportion * 100)%, Total Deviant Points: \(totalDeviantPoints), Total Points: \(totalPoints)"
        )
        return statusDetails
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
