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
    var classificationBuffer: MTLBuffer
    var vertexCount: Int
    var indexCount: Int
    var faceCount: Int
    var generation: Int = 0
}

enum MeshSnapshotError: Error, LocalizedError {
    case bufferTooSmall(expected: Int, actual: Int)
    
    var errorDescription: String? {
        switch self {
        case .bufferTooSmall(let expected, let actual):
            return "Buffer too small. Expected at least \(expected) bytes, but got \(actual) bytes."
        }
    }
}

/**
 Functionality to capture ARMeshAnchor data as a GPU-friendly snapshot
 */
final class MeshGPUSnapshotCreator: NSObject {
    func snapshotAnchors(_ anchors: [ARAnchor]) throws -> [MeshAnchorGPU] {
        var meshSnapshots: [MeshAnchorGPU] = []
        for anchor in anchors {
            guard let meshAnchor = anchor as? ARMeshAnchor else { continue }
            let meshSnapshot = createSnapshot(meshAnchor: meshAnchor)
            meshSnapshots.append(meshSnapshot)
        }
        return meshSnapshots
    }
    
    func createSnapshot(meshAnchor: ARMeshAnchor) -> MeshAnchorGPU {
        
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
}
