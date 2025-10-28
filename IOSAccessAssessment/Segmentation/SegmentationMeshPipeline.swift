//
//  SegmentationMeshPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 10/28/25.
//

import SwiftUI
import ARKit
import RealityKit
import simd

enum SegmentationMeshPipelineError: Error, LocalizedError {
    case isProcessingTrue
    case emptySegmentation
    case unexpectedError
    
    var errorDescription: String? {
        switch self {
        case .isProcessingTrue:
            return "The Segmentation Mesh Pipeline is already processing a request."
        case .emptySegmentation:
            return "The Segmentation Image does not contain any valid segmentation data."
        case .unexpectedError:
            return "An unexpected error occurred in the Segmentation Mesh Pipeline."
        }
    }
}

struct SegmentationMeshPipelineResults {
    var modelEntities: [UUID: ModelEntity] = [:]
    var assignedColors: [UUID: UIColor] = [:]
}

/**
 A class to generate 3D mesh models from segmentation data to help integrate them into an AR scene.
 */
final class SegmentationMeshPipeline: ObservableObject {
    private var isProcessing = false
    private var currentTask: Task<SegmentationMeshPipelineResults, Error>?
    
    private var selectionClasses: [Int] = []
    private var selectionClassLabels: [UInt8] = []
    private var selectionClassGrayscaleValues: [Float] = []
    private var selectionClassColors: [CIColor] = []
    
    func reset() {
        self.isProcessing = false
        self.setSelectionClasses([])
    }
    
    func setSelectionClasses(_ selectionClasses: [Int]) {
        self.selectionClasses = selectionClasses
        self.selectionClassLabels = selectionClasses.map { Constants.SelectedSegmentationConfig.labels[$0] }
        self.selectionClassGrayscaleValues = selectionClasses.map { Constants.SelectedSegmentationConfig.grayscaleValues[$0] }
        self.selectionClassColors = selectionClasses.map { Constants.SelectedSegmentationConfig.colors[$0] }
    }
    
    /**
     Function to process the anchor data with the given segmentation results.
     */
    func processRequest(
        with anchors: [ARAnchor], segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        highPriority: Bool = false
    ) async throws -> SegmentationMeshPipelineResults {
        if (highPriority) {
            self.currentTask?.cancel()
        } else {
            if ((currentTask != nil) && !currentTask!.isCancelled) {
                throw SegmentationMeshPipelineError.isProcessingTrue
            }
        }
        
        let newTask = Task { [weak self] () throws -> SegmentationMeshPipelineResults in
            guard let self = self else { throw SegmentationMeshPipelineError.unexpectedError }
            defer {
                self.currentTask = nil
            }
            try Task.checkCancellation()
            
            return try self.processMesh(with: anchors, segmentationImage: segmentationImage,
                cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics)
        }
        
        self.currentTask = newTask
        return try await newTask.value
    }
    
    /**
        Private function to process the mesh anchors and generate 3D models based on segmentation data.
     
        Note: Assumes that the segmentationImage dimensions match the camera image dimensions.
     */
    private func processMesh(
        with anchors: [ARAnchor], segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) throws -> SegmentationMeshPipelineResults {
        guard let segmentationPixelBuffer = segmentationImage.pixelBuffer else {
            throw SegmentationMeshPipelineError.emptySegmentation
        }
        
        CVPixelBufferLockBaseAddress(segmentationPixelBuffer, .readOnly)
        let width = CVPixelBufferGetWidth(segmentationPixelBuffer)
        let height = CVPixelBufferGetHeight(segmentationPixelBuffer)
        let bpr = CVPixelBufferGetBytesPerRow(segmentationPixelBuffer)
        defer { CVPixelBufferUnlockBaseAddress(segmentationPixelBuffer, .readOnly) }
        
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        
        var triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = []
        var triangleNormals: [SIMD3<Float>] = []
        
        for meshAnchor in meshAnchors {
            let geometry = meshAnchor.geometry
            let transform = meshAnchor.transform
            
            let faces = geometry.faces
            let classifications = geometry.classification
            
            guard let classifications = classifications else {
                continue
            }
            for index in 0..<faces.count {
                let face = faces[index]
                let classification = getClassification(at: Int(index), classifications: classifications)
                
            }
        }
        
        return SegmentationMeshPipelineResults(modelEntities: [:], assignedColors: [:])
    }
    
    
}

/**
 Helper methods to retrieve mesh-related data.
 
 NOTE: It may be prudent to move these to a separate utility file, or add these as extensions to ARMeshGeometry.
 */
extension SegmentationMeshPipeline {
    private func getClassification(at vertexIndex: Int, classifications: ARGeometrySource) -> ARMeshClassification {
        let classificationAddress = classifications.buffer.contents().advanced(by: classifications.offset + (classifications.stride * Int(vertexIndex)))
        let classificationValue = Int(classificationAddress.assumingMemoryBound(to: UInt8.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }
}
