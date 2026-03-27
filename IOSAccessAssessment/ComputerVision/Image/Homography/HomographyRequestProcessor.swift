//
//  HomographyRequestProcessor.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/5/25.
//
import Vision
import simd
import CoreImage

enum HomographyRequestProcessorError: Error, LocalizedError {
    case homographyProcessingError
    
    var errorDescription: String? {
        switch self {
        case .homographyProcessingError:
            return "Error occurred while processing the homography request."
        }
    }
}

struct HomographyRequestProcessor {
    /// Computes the homography transform for the reference image and the floating image.
    func getHomographyTransform(
        referenceImage: CIImage, floatingImage: CIImage, orientation: CGImagePropertyOrientation = .up
    ) throws -> simd_float3x3 {
        let imageRequestHandler = VNImageRequestHandler(ciImage: referenceImage, orientation: orientation, options: [:])
        let transformRequest = VNHomographicImageRegistrationRequest(targetedCIImage: floatingImage, orientation: orientation)
        try imageRequestHandler.perform([transformRequest])
        guard let transformResult = transformRequest.results else {
            throw HomographyRequestProcessorError.homographyProcessingError
        }
        let transformMatrix = transformResult.first?.warpTransform
        guard let matrix = transformMatrix else {
            throw HomographyRequestProcessorError.homographyProcessingError
        }
        return matrix
    }
    
    /// Computes the approximate homography transform from the camera intrinsics and extrinsics.
    /// WARNING: This is an approximate method that assumes the translation delta is negligible.
    /// WARNING: Not implemented yet.
//    func getHomographyTransform(
//        referenceImageTransform: simd_float4x4, referenceImageIntrinsics: simd_float3x3,
//        floatingImageTransform: simd_float4x4, floatingImageIntrinsics: simd_float3x3
//    ) throws -> simd_float3x3 {
//        throw HomographyRequestProcessorError.homographyProcessingError
//    }
}
