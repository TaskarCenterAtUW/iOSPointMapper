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
    case meshPipelineBlitEncoderError
    
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
        case .meshPipelineBlitEncoderError:
            return "Failed to create Blit Command Encoder for the pipeline."
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
    
    let countPipeline: MTLComputePipelineState
    let stdPipeline: MTLComputePipelineState
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
        
        guard let countKernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "countDeviantNormals"),
              let countPipeline = try? device.makeComputePipelineState(function: countKernelFunction) else {
            throw SurfaceIntegrityProcessorError.metalInitializationFailed
        }
        self.countPipeline = countPipeline
        guard let stdKernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "stdFromNormals"),
              let stdPipeline = try? device.makeComputePipelineState(function: stdKernelFunction) else {
            throw SurfaceIntegrityProcessorError.metalInitializationFailed
        }
        self.stdPipeline = stdPipeline
    }
    
    /**
        Main function to get surface integrity results from image data. Calls individual integrity assessment functions and aggregates results.
     */
    func getIntegrityResultsFromImage(
        worldPointsGrid: WorldPointsGrid,
        plane: Plane,
        surfaceNormalsForPointsGrid: SurfaceNormalsForPointsGrid,
        damageDetectionResults: [DamageDetectionResult],
        captureData: (any CaptureImageDataProtocol)
    ) throws -> IntegrityResults {
        let surfaceNormalIntegrityResult = try getSurfaceNormalIntegrityResultFromImage(
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
        let boundingBoxSurfaceNormalIntegrityResult = try getBoundingBoxSurfaceNormalIntegrityResultFromImage(
            worldPointsGrid: worldPointsGrid,
            plane: plane,
            surfaceNormalsForPointsGrid: surfaceNormalsForPointsGrid,
            damageDetectionResults: damageDetectionResults,
            captureData: captureData
        )
        let integrityResults = IntegrityResults(
            surfaceNormalStatusDetails: surfaceNormalIntegrityResult,
            boundingBoxAreaStatusDetails: boundingBoxAreaIntegrityResult,
            boundingBoxSurfaceNormalStatusDetails: boundingBoxSurfaceNormalIntegrityResult
        )
        debugIntegrityResults(integrityResults: integrityResults)
        return integrityResults
    }
    
    /**
     CPU implementation for surface integrity assessment from image. Used for benchmarking and fallback when Metal processing is not available.
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
        let integrityResults = IntegrityResults(
            surfaceNormalStatusDetails: surfaceNormalIntegrityResult,
            boundingBoxAreaStatusDetails: boundingBoxAreaIntegrityResult,
            boundingBoxSurfaceNormalStatusDetails: boundingBoxSurfaceNormalIntegrityResult
        )
        debugIntegrityResults(integrityResults: integrityResults)
        return integrityResults
    }
    
    private func debugIntegrityResults(integrityResults: IntegrityResults) {
        print("Surface Normal Integrity Status: \(integrityResults.surfaceNormalStatusDetails.status) - \(integrityResults.surfaceNormalStatusDetails.details)")
        print("Bounding Box Area Integrity Status: \(integrityResults.boundingBoxAreaStatusDetails.status) - \(integrityResults.boundingBoxAreaStatusDetails.details)")
        print("Bounding Box Surface Normal Integrity Status: \(integrityResults.boundingBoxSurfaceNormalStatusDetails.status) - \(integrityResults.boundingBoxSurfaceNormalStatusDetails.details)")
    }
    
    /**
     Get angular deviation between normalized vectors v1 and v2 in degrees.
     */
    func getAngularDeviation(_ nv1: simd_float3, _ nv2: simd_float3) -> Float {
        let dotProduct = simd_dot(nv1, nv2)
        let angleInRadians = acos(dotProduct)
        let angleInDegrees = angleInRadians * (180.0 / .pi)
        return angleInDegrees
    }
}
