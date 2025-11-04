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
    private var meshAnchorsGPU: [UUID: MeshAnchorGPU] = [:]
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func buffers(for anchorId: UUID) -> MeshAnchorGPU? {
        return meshAnchorsGPU[anchorId]
    }
    
    func snapshotAnchors(_ anchors: [ARAnchor]) throws {
        for anchor in anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
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
        
        var meshAnchorGPU: MeshAnchorGPU = try meshAnchorsGPU[meshAnchor.identifier] ?? {
            let vertexBuffer = try makeBuffer(device: device, length: defaultBufferSize, options: .storageModeShared)
            let indexBuffer = try makeBuffer(device: device, length: defaultBufferSize, options: .storageModeShared)
            return MeshAnchorGPU(vertexBuffer: vertexBuffer, indexBuffer: indexBuffer, classificationBuffer: nil)
        }()
        
        // Assign vertex buffer
        let vertexElemSize = MemoryLayout<Float>.stride * 3
        let vertexByteCount = vertices.count * vertexElemSize
        try ensureCapacity(device: device, buf: &meshAnchorGPU.vertexBuffer, requiredBytes: vertexByteCount)
        
        let vertexSrcPtr = vertices.buffer.contents().advanced(by: vertices.offset)
        if (vertices.stride == vertexElemSize) {
            try copyContiguous(srcPtr: vertexSrcPtr, dst: meshAnchorGPU.vertexBuffer, byteCount: vertexByteCount)
        } else {
            try copyStrided(count: vertices.count, srcPtr: vertexSrcPtr, srcStride: vertices.stride,
                            dst: meshAnchorGPU.vertexBuffer, elemSize: vertexElemSize)
        }
        meshAnchorGPU.vertexCount = vertices.count
        
        // Assign index buffer
        // MARK: This code assumes the index type will always be only UInt32
        let indexTypeSize = MemoryLayout<UInt32>.stride
        let indexByteCount = faces.count * faces.bytesPerIndex * faces.indexCountPerPrimitive
        try ensureCapacity(device: device, buf: &meshAnchorGPU.indexBuffer, requiredBytes: indexByteCount)
        
        let indexSrcPtr = faces.buffer.contents()
        if (faces.bytesPerIndex == indexTypeSize) {
            try copyContiguous(srcPtr: indexSrcPtr, dst: meshAnchorGPU.indexBuffer, byteCount: indexByteCount)
        } else {
            try copyStrided(count: faces.count * faces.indexCountPerPrimitive, srcPtr: indexSrcPtr, srcStride: faces.bytesPerIndex,
                            dst: meshAnchorGPU.indexBuffer, elemSize: indexTypeSize)
        }
        
        // Assign classification buffer (if available)
        if let classifications = classifications {
            let classificationElemSize = MemoryLayout<UInt8>.stride
            let classificationByteCount = classifications.count * classificationElemSize
            if meshAnchorGPU.classificationBuffer == nil {
                let newCapacity = nextCap(classificationByteCount)
                meshAnchorGPU.classificationBuffer = try makeBuffer(device: device, length: newCapacity, options: .storageModeShared)
            } else {
                try ensureCapacity(device: device, buf: &meshAnchorGPU.classificationBuffer!, requiredBytes: classificationByteCount)
            }
            let classificationSrcPtr = classifications.buffer.contents().advanced(by: classifications.offset)
            if (classifications.stride == classificationElemSize) {
                try copyContiguous(srcPtr: classificationSrcPtr, dst: meshAnchorGPU.classificationBuffer!, byteCount: classificationByteCount)
            } else {
                try copyStrided(count: classifications.count, srcPtr: classificationSrcPtr, srcStride: classifications.stride,
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
    
    @inline(__always)
    func copyContiguous(srcPtr: UnsafeRawPointer, dst: MTLBuffer, byteCount: Int) throws {
        guard byteCount <= dst.length else {
            throw MeshSnapshotError.bufferTooSmall(expected: byteCount, actual: dst.length)
        }
        let dstPtr = dst.contents()
        dstPtr.copyMemory(from: srcPtr, byteCount: byteCount)
    }
    
    @inline(__always)
    func copyStrided(count: Int, srcPtr: UnsafeRawPointer, srcStride: Int,
                     dst: MTLBuffer, elemSize: Int) throws {
        guard count * elemSize <= dst.length else {
            throw MeshSnapshotError.bufferTooSmall(expected: count * elemSize, actual: dst.length)
        }
        let dstPtr = dst.contents()
        for i in 0..<count {
            let srcElemPtr = srcPtr.advanced(by: i * srcStride)
            let dstElemPtr = dstPtr.advanced(by: i * elemSize)
            dstElemPtr.copyMemory(from: srcElemPtr, byteCount: elemSize)
        }
    }
    
    @inline(__always)
    func ensureCapacity(device: MTLDevice, buf: inout MTLBuffer, requiredBytes: Int) throws {
        if buf.length < requiredBytes {
            let newCapacity = nextCap(requiredBytes)
            buf = try makeBuffer(device: device, length: newCapacity, options: .storageModeShared)
        }
    }
    
    @inline(__always)
    func makeBuffer(device: MTLDevice, length: Int, options: MTLResourceOptions = .storageModeShared) throws -> MTLBuffer {
        guard let buffer = device.makeBuffer(length: length, options: options) else {
            throw MeshSnapshotError.bufferCreationFailed
        }
        return buffer
    }
    
    /**
    Calculate the next power-of-two capacity greater than or equal to needed
     */
    @inline(__always)
    func nextCap(_ needed: Int, minimum: Int = 1024) -> Int {
        let maximum: Int = Int.max >> 2
        if needed > maximum {
            return Int.max
        }
        var c = max(needed, minimum)
        c -= 1; c |= c>>1; c |= c>>2; c |= c>>4; c |= c>>8; c |= c>>16
        return c + 1
    }
}
