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

enum SegmentationMeshGPUPipelineError: Error, LocalizedError {
    case isProcessingTrue
    case metalInitializationError
    case metalPipelineCreationError
    case meshPipelineBlitEncoderError
    case unexpectedError
    
    var errorDescription: String? {
        switch self {
        case .isProcessingTrue:
            return "The Segmentation Mesh Pipeline is already processing a request."
        case .metalInitializationError:
            return "Failed to initialize Metal resources for the Segmentation Mesh Pipeline."
        case .metalPipelineCreationError:
            return "Failed to create Metal pipeline state for the Segmentation Mesh Pipeline."
        case .meshPipelineBlitEncoderError:
            return "Failed to create Blit Command Encoder for the Segmentation Mesh Pipeline."
        case .unexpectedError:
            return "An unexpected error occurred in the Segmentation Mesh Pipeline."
        }
    }
}

/**
 These structs mirror the Metal shader structs for data exchange.
 TODO: Create a bridging header to use the Metal structs directly.
 */
struct SegmentationMeshGPUPipelineResults {
    let triangles: [MeshTriangle]
}

final class SegmentationMeshGPUPipeline: ObservableObject {
    private var isProcessing = false
    private var currentTask: Task<SegmentationMeshGPUPipelineResults, Error>?
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
    ) async throws -> SegmentationMeshGPUPipelineResults {
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
            
            return try await self.processMeshAnchorsWithTimeout(
                with: meshAnchorSnapshot, segmentationImage: segmentationImage,
                cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics
            )
        }
        
        self.currentTask = newTask
        return try await newTask.value
    }
    
    private func processMeshAnchorsWithTimeout(
        with meshAnchorSnapshot: [UUID: MeshAnchorGPU], segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) async throws -> SegmentationMeshGPUPipelineResults {
        return try await withThrowingTaskGroup(of: SegmentationMeshGPUPipelineResults.self) { group in
            group.addTask {
                return try await self.processMeshAnchors(
                    with: meshAnchorSnapshot, segmentationImage: segmentationImage,
                    cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeoutInSeconds))
                throw SegmentationMeshGPUPipelineError.unexpectedError
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /**
        Private function to process the mesh anchors and generate 3D models based on segmentation data.
     
        Note: Assumes that the segmentationImage dimensions match the camera image dimensions.
     */
    private func processMeshAnchors(
        with meshAnchorSnapshot: [UUID: MeshAnchorGPU], segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) async throws -> SegmentationMeshGPUPipelineResults {
        guard let segmentationPixelBuffer = segmentationImage.pixelBuffer else {
            throw SegmentationMeshPipelineError.emptySegmentation
        }
        
        let totalFaceCount = meshAnchorSnapshot.reduce(0) { $0 + $1.value.faceCount }
        let outBytes = totalFaceCount * MemoryLayout<MeshTriangle>.stride
        var triangleOutBuffer: MTLBuffer = try MeshBufferUtils.makeBuffer(
            device: self.device, length: MeshBufferUtils.defaultBufferSize, options: .storageModeShared
        )
        try MeshBufferUtils.ensureCapacity(device: self.device, buf: &triangleOutBuffer, requiredBytes: outBytes)
        let triangleOutCount: MTLBuffer = try MeshBufferUtils.makeBuffer(
            device: self.device, length: MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
        // For debugging
        let debugSlots = Int(3) // MARK: Hard-coded
        let debugBytes = debugSlots * MemoryLayout<UInt32>.stride
        let debugCounter: MTLBuffer = try MeshBufferUtils.makeBuffer(
            device: self.device, length: debugBytes, options: .storageModeShared
        )
        
        // Set up additional parameters
        let viewMatrix = simd_inverse(cameraTransform)
        let imageSize = simd_uint2(UInt32(CVPixelBufferGetWidth(segmentationPixelBuffer)),
                                      UInt32(CVPixelBufferGetHeight(segmentationPixelBuffer)))
        
        // Set up the Metal command buffer
        guard let commandBuffer = self.commandQueue.makeCommandBuffer() else {
            throw SegmentationMeshGPUPipelineError.metalPipelineCreationError
        }
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw SegmentationMeshGPUPipelineError.meshPipelineBlitEncoderError
        }
        blit.fill(buffer: triangleOutCount, range: 0..<MemoryLayout<UInt32>.stride, value: 0)
        blit.fill(buffer: debugCounter, range: 0..<debugBytes, value: 0)
        blit.endEncoding()
        let threadGroupSizeWidth = min(self.pipelineState.maxTotalThreadsPerThreadgroup, 256)
        
        for (_, meshAnchorGPU) in meshAnchorSnapshot {
            guard meshAnchorGPU.faceCount > 0 else { continue }
            
            let hasClass: UInt32 = meshAnchorGPU.classificationBuffer != nil ? 1 : 0
            var params = FaceParams(
                faceCount: UInt32(meshAnchorGPU.faceCount), totalCount: UInt32(totalFaceCount),
                indicesPerFace: 3, hasClass: hasClass,
                anchorTransform: meshAnchorGPU.anchorTransform, cameraTransform: cameraTransform,
                viewMatrix: viewMatrix, intrinsics: cameraIntrinsics, imageSize: imageSize
            )
            let paramsBuffer = try MeshBufferUtils.makeBuffer(
                device: self.device, length: MemoryLayout<FaceParams>.stride, options: .storageModeShared
            )
            let paramsPointer = paramsBuffer.contents()
            paramsPointer.copyMemory(from: &params, byteCount: MemoryLayout<FaceParams>.stride)
            
            guard let commandEncoder = commandBuffer.makeComputeCommandEncoder() else {
                throw SegmentationMeshGPUPipelineError.metalPipelineCreationError
            }
            commandEncoder.setComputePipelineState(self.pipelineState)
            commandEncoder.setBuffer(meshAnchorGPU.vertexBuffer, offset: 0, index: 0)
            commandEncoder.setBuffer(meshAnchorGPU.indexBuffer, offset: 0, index: 1)
            commandEncoder.setBuffer(meshAnchorGPU.classificationBuffer ?? nil, offset: 0, index: 2)
            commandEncoder.setBuffer(triangleOutBuffer, offset: 0, index: 3)
            commandEncoder.setBuffer(triangleOutCount, offset: 0, index: 4)
            commandEncoder.setBuffer(paramsBuffer, offset: 0, index: 5)
            commandEncoder.setBuffer(debugCounter, offset: 0, index: 6)
            
            let threadGroupSize = MTLSize(width: threadGroupSizeWidth, height: 1, depth: 1)
            let threadGroups = MTLSize(
                width: (meshAnchorGPU.faceCount + threadGroupSize.width - 1) / threadGroupSize.width, height: 1, depth: 1
            )
            commandEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
            commandEncoder.endEncoding()
        }
        commandBuffer.commit()
        await commandBuffer.completed()
        
        // Read back the results
        let triangleOutCountPointer = triangleOutCount.contents().bindMemory(to: UInt32.self, capacity: 1)
        let triangleOutCountValue = triangleOutCountPointer.pointee
        let triangleOutBufferPointer = triangleOutBuffer.contents().bindMemory(
            to: MeshTriangle.self, capacity: Int(triangleOutCountValue)
        )
        let triangleOutBufferView = UnsafeBufferPointer(
            start: triangleOutBufferPointer, count: Int(triangleOutCountValue)
        )
        let triangles = Array(triangleOutBufferView)
        
        let debugCountPointer = debugCounter.contents().bindMemory(to: UInt32.self, capacity: debugSlots)
        var debugCountValue: [UInt32] = []
        for i in 0..<debugSlots {
            debugCountValue.append(debugCountPointer.advanced(by: i).pointee)
        }
        print("Total Count: \(totalFaceCount), Processed Triangle Count: \(triangleOutCountValue), Debug Count: \(debugCountValue)")
        return SegmentationMeshGPUPipelineResults(triangles: triangles)
    }
}
