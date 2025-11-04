//
//  SegmentationMeshGPUPipeline.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//

import SwiftUI
import ARKit
import RealityKit
import simd
import Metal

enum SegmentationMeshGPUPipelineError: Error, LocalizedError {
    case isProcessingTrue
    case metalInitializationError
    case metalPipelineCreationError
    case unexpectedError
    
    var errorDescription: String? {
        switch self {
        case .isProcessingTrue:
            return "The Segmentation Mesh Pipeline is already processing a request."
        case .metalInitializationError:
            return "Failed to initialize Metal resources for the Segmentation Mesh Pipeline."
        case .metalPipelineCreationError:
            return "Failed to create Metal pipeline state for the Segmentation Mesh Pipeline."
        case .unexpectedError:
            return "An unexpected error occurred in the Segmentation Mesh Pipeline."
        }
    }
}

struct FaceOut {
    var centroid: simd_float3
    var normal: simd_float3
    var cls: CUnsignedChar
    var visible: CUnsignedChar
    var _pad: CUnsignedShort
}

struct FaceParams {
    var faceCount: UInt32
    var indicesPerFace: UInt32
    var hasClass: Bool
    var worldFromLocal: simd_float4x4
    var viewProj: simd_float4x4
}

final class SegmentationMeshGPUPipeline: ObservableObject {
    private var isProcessing = false
    private var currentTask: Task<Void, Error>?
    private var timeoutInSeconds: Double = 1.0
    
    private var selectionClasses: [Int] = []
    private var selectionClassLabels: [UInt8] = []
    private var selectionClassGrayscaleValues: [Float] = []
    private var selectionClassColors: [CIColor] = []
    private var selectionClassNames: [String] = []
    private var selectionClassMeshClassifications: [[ARMeshClassification]?] = []
    private var selectionClassLabelToIndexMap: [UInt8: Int] = [:]
    
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipelineState: MTLComputePipelineState
    let paramsBuffer: MTLBuffer
    
    init(device: MTLDevice) throws {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else  {
            throw SegmentationMeshGPUPipelineError.metalInitializationError
        }
        self.commandQueue = commandQueue
        guard let kernelFunction = device.makeDefaultLibrary()?.makeFunction(name: "processMesh") else {
            throw SegmentationMeshGPUPipelineError.metalInitializationError
        }
        self.pipelineState = try device.makeComputePipelineState(function: kernelFunction)
        self.paramsBuffer = device.makeBuffer(length: MemoryLayout<FaceParams>.stride,
                                              options: .storageModeShared)!
    }
    
    func reset() {
        self.isProcessing = false
        self.setSelectionClasses([])
    }
    
    func setSelectionClasses(_ selectionClasses: [Int]) {
        self.selectionClasses = selectionClasses
        self.selectionClassLabels = selectionClasses.map { Constants.SelectedSegmentationConfig.labels[$0] }
        self.selectionClassGrayscaleValues = selectionClasses.map { Constants.SelectedSegmentationConfig.grayscaleValues[$0] }
        self.selectionClassColors = selectionClasses.map { Constants.SelectedSegmentationConfig.colors[$0] }
        self.selectionClassNames = selectionClasses.map { Constants.SelectedSegmentationConfig.classNames[$0] }
        self.selectionClassMeshClassifications = selectionClasses.map {
            Constants.SelectedSegmentationConfig.classes[$0].meshClassification ?? nil
        }
        
        var selectionClassLabelToIndexMap: [UInt8: Int] = [:]
        for (index, label) in self.selectionClassLabels.enumerated() {
            selectionClassLabelToIndexMap[label] = index
        }
        self.selectionClassLabelToIndexMap = selectionClassLabelToIndexMap
    }
    
    func processRequest(
        with meshAnchorSnapshot: [UUID: MeshAnchorGPU], segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        highPriority: Bool = false
    ) async throws {
        if (highPriority) {
            self.currentTask?.cancel()
        } else {
            if ((currentTask != nil) && !currentTask!.isCancelled) {
                throw SegmentationMeshGPUPipelineError.isProcessingTrue
            }
        }
        
        let newTask = Task { [weak self] () throws in
            guard let self = self else { throw SegmentationMeshGPUPipelineError.unexpectedError }
            defer {
                self.currentTask = nil
            }
            try Task.checkCancellation()
            
            try await self.processMeshAnchorsWithTimeout(
                with: meshAnchorSnapshot, segmentationImage: segmentationImage,
                cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
            )
            try Task.checkCancellation()
        }
        
        self.currentTask = newTask
        return try await newTask.value
    }
    
    private func processMeshAnchorsWithTimeout(
        with meshAnchorSnapshot: [UUID: MeshAnchorGPU], segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                return try await self.processMeshAnchors(
                    with: meshAnchorSnapshot, segmentationImage: segmentationImage,
                    cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeoutInSeconds))
                throw SegmentationMeshGPUPipelineError.unexpectedError
            }
            try await group.next()!
            group.cancelAll()
        }
    }
    
    /**
        Private function to process the mesh anchors and generate 3D models based on segmentation data.
     
        Note: Assumes that the segmentationImage dimensions match the camera image dimensions.
     */
    private func processMeshAnchors(
        with meshAnchorSnapshot: [UUID: MeshAnchorGPU], segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) async throws {
        guard let segmentationPixelBuffer = segmentationImage.pixelBuffer else {
            throw SegmentationMeshPipelineError.emptySegmentation
        }
        
        await withTaskGroup(of: Void.self) { group in
            for (_, meshAnchorGPU) in meshAnchorSnapshot {
                group.addTask {
                    do {
                        let outBytes = meshAnchorGPU.faceCount * MemoryLayout<FaceOut>.stride
                        var faceOutBuffer: MTLBuffer = try MeshBufferUtils.makeBuffer(
                            device: self.device, length: MeshBufferUtils.defaultBufferSize, options: .storageModeShared
                        )
                        try MeshBufferUtils.ensureCapacity(device: self.device, buf: &faceOutBuffer, requiredBytes: outBytes)
                        try self.processMeshAnchor(
                            meshAnchorGPU: meshAnchorGPU, segmentationPixelBuffer: segmentationPixelBuffer,
                            cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics,
                            outBuffer: faceOutBuffer
                        )
                    } catch {
                        print("Error processing mesh anchor: \(error.localizedDescription)")
                    }
                }
            }
            await group.waitForAll()
        }
    }
    
    private func processMeshAnchor(
        meshAnchorGPU: MeshAnchorGPU, segmentationPixelBuffer: CVPixelBuffer,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3,
        outBuffer: MTLBuffer
    ) throws {
        guard meshAnchorGPU.faceCount > 0 else { return }
        guard let commandBuffer = self.commandQueue.makeCommandBuffer(),
              let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw SegmentationMeshGPUPipelineError.metalPipelineCreationError
        }
        commandEncoder.setComputePipelineState(self.pipelineState)
        
        commandEncoder.setBuffer(meshAnchorGPU.vertexBuffer, offset: 0, index: 0)
        commandEncoder.setBuffer(meshAnchorGPU.indexBuffer, offset: 0, index: 1)
        if let classificationBuffer = meshAnchorGPU.classificationBuffer {
            commandEncoder.setBuffer(classificationBuffer, offset: 0, index: 2)
        } else {
            commandEncoder.setBuffer(nil, offset: 0, index: 2)
        }
        commandEncoder.setBuffer(outBuffer, offset: 0, index: 3)
        var params = FaceParams(
            faceCount: UInt32(meshAnchorGPU.faceCount), indicesPerFace: 3, hasClass: meshAnchorGPU.classificationBuffer != nil,
            worldFromLocal: cameraTransform, viewProj: cameraTransform
        )
        let paramsBufferPointer = paramsBuffer.contents()
        paramsBufferPointer.copyMemory(from: &params, byteCount: MemoryLayout<FaceParams>.stride)
        commandEncoder.setBuffer(paramsBuffer, offset: 0, index: 4)
        
        let threadGroupSize = MTLSize(width: min(self.pipelineState.maxTotalThreadsPerThreadgroup, 256), height: 1, depth: 1)
        let threadGroups = MTLSize(
            width: (meshAnchorGPU.faceCount + threadGroupSize.width - 1) / threadGroupSize.width, height: 1, depth: 1
        )
        commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        commandEncoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}
