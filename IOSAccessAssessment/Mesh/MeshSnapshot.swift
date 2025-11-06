//
//  MeshSnapshot.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//
import ARKit
import RealityKit

struct MeshAnchorGPU {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var classificationBuffer: MTLBuffer? = nil
    var anchorTransform: simd_float4x4
    var vertexCount: Int = 0
    var indexCount: Int = 0
    var faceCount: Int = 0
    var generation: Int = 0
}

enum MeshSnapshotError: Error, LocalizedError {
    case bufferTooSmall(expected: Int, actual: Int)
    case bufferCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .bufferTooSmall(let expected, let actual):
            return "Buffer too small. Expected at least \(expected) bytes, but got \(actual) bytes."
        case .bufferCreationFailed:
            return "Failed to create MTLBuffer."
        }
    }
}

/**
 Functionality to capture ARMeshAnchor data as a GPU-friendly snapshot
 */
final class MeshGPUSnapshotGenerator: NSObject {
    private let defaultBufferSize: Int = 1024
    
    private let device: MTLDevice
    var meshAnchorsGPU: [UUID: MeshAnchorGPU] = [:]
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func buffers(for anchorId: UUID) -> MeshAnchorGPU? {
        return meshAnchorsGPU[anchorId]
    }
    
    func snapshotAnchors(_ anchors: [ARAnchor]) throws {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        for (_, meshAnchor) in meshAnchors.enumerated() {
            try createSnapshot(meshAnchor: meshAnchor)
        }
    }
    
    func removeAnchors(_ anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            meshAnchorsGPU.removeValue(forKey: meshAnchor.identifier)
        }
    }
    
    /**
    Create or update the GPU snapshot for the given ARMeshAnchor
     
     TODO: Check possibility of blitting directly from MTLBuffer to MTLBuffer using a blit command encoder for better performance
     */
    func createSnapshot(meshAnchor: ARMeshAnchor) throws {
        let geometry = meshAnchor.geometry
        let vertices = geometry.vertices               // ARGeometrySource (format .float3)
        let faces = geometry.faces                  // ARGeometryElement
        let classifications = geometry.classification
        let anchorTransform = meshAnchor.transform
        
        var meshAnchorGPU: MeshAnchorGPU = try meshAnchorsGPU[meshAnchor.identifier] ?? {
            let vertexBuffer = try MeshBufferUtils.makeBuffer(device: device, length: defaultBufferSize, options: .storageModeShared)
            let indexBuffer = try MeshBufferUtils.makeBuffer(device: device, length: defaultBufferSize, options: .storageModeShared)
            return MeshAnchorGPU(
                vertexBuffer: vertexBuffer, indexBuffer: indexBuffer, classificationBuffer: nil, anchorTransform: anchorTransform
            )
        }()
        
        // Assign vertex buffer
        let vertexElemSize = MemoryLayout<Float>.stride * 3
        let vertexByteCount = vertices.count * vertexElemSize
        try MeshBufferUtils.ensureCapacity(device: device, buf: &meshAnchorGPU.vertexBuffer, requiredBytes: vertexByteCount)
        
        let vertexSrcPtr = vertices.buffer.contents().advanced(by: vertices.offset)
        if (vertices.stride == vertexElemSize) {
            try MeshBufferUtils.copyContiguous(srcPtr: vertexSrcPtr, dst: meshAnchorGPU.vertexBuffer, byteCount: vertexByteCount)
        } else {
            try MeshBufferUtils.copyStrided(count: vertices.count, srcPtr: vertexSrcPtr, srcStride: vertices.stride,
                            dst: meshAnchorGPU.vertexBuffer, elemSize: vertexElemSize)
        }
        meshAnchorGPU.vertexCount = vertices.count
        
        // Assign index buffer
        // MARK: This code assumes the index type will always be only UInt32
        let indexTypeSize = MemoryLayout<UInt32>.stride
        let indexByteCount = faces.count * faces.bytesPerIndex * faces.indexCountPerPrimitive
        try MeshBufferUtils.ensureCapacity(device: device, buf: &meshAnchorGPU.indexBuffer, requiredBytes: indexByteCount)
        
        let indexSrcPtr = faces.buffer.contents()
        if (faces.bytesPerIndex == indexTypeSize) {
            try MeshBufferUtils.copyContiguous(srcPtr: indexSrcPtr, dst: meshAnchorGPU.indexBuffer, byteCount: indexByteCount)
        } else {
            try MeshBufferUtils.copyStrided(count: faces.count * faces.indexCountPerPrimitive, srcPtr: indexSrcPtr, srcStride: faces.bytesPerIndex,
                            dst: meshAnchorGPU.indexBuffer, elemSize: indexTypeSize)
        }
        
        // Assign classification buffer (if available)
        if let classifications = classifications {
            let classificationElemSize = MemoryLayout<UInt8>.stride
            let classificationByteCount = classifications.count * classificationElemSize
            if meshAnchorGPU.classificationBuffer == nil {
                let newCapacity = MeshBufferUtils.nextCap(classificationByteCount)
                meshAnchorGPU.classificationBuffer = try MeshBufferUtils.makeBuffer(device: device, length: newCapacity, options: .storageModeShared)
            } else {
                try MeshBufferUtils.ensureCapacity(device: device, buf: &meshAnchorGPU.classificationBuffer!, requiredBytes: classificationByteCount)
            }
            let classificationSrcPtr = classifications.buffer.contents().advanced(by: classifications.offset)
            if (classifications.stride == classificationElemSize) {
                try MeshBufferUtils.copyContiguous(
                    srcPtr: classificationSrcPtr, dst: meshAnchorGPU.classificationBuffer!, byteCount: classificationByteCount
                )
            } else {
                try MeshBufferUtils.copyStrided(
                    count: classifications.count, srcPtr: classificationSrcPtr, srcStride: classifications.stride,
                    dst: meshAnchorGPU.classificationBuffer!, elemSize: classificationElemSize)
            }
        } else {
            meshAnchorGPU.classificationBuffer = nil
        }
        
        meshAnchorGPU.indexCount = faces.count * faces.indexCountPerPrimitive
        meshAnchorGPU.faceCount = faces.count
        meshAnchorGPU.generation += 1
        meshAnchorsGPU[meshAnchor.identifier] = meshAnchorGPU
    }
}
