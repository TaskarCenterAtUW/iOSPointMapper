//
//  MeshSnapshot.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//
import ARKit
import RealityKit

struct MeshGPUAnchor {
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    var classificationBuffer: MTLBuffer? = nil
    var anchorTransform: simd_float4x4
    var vertexCount: Int = 0
    var indexCount: Int = 0
    var faceCount: Int = 0
    var generation: Int = 0
}

struct MeshGPUSnapshot {
    let vertexStride: Int
    let vertexOffset: Int
    let indexStride: Int
    let classificationStride: Int
    let anchors: [UUID: MeshGPUAnchor]
}

/**
 Functionality to capture ARMeshAnchor data as a GPU-friendly snapshot
 */
final class MeshGPUSnapshotGenerator: NSObject {
    // MARK: These constants can be made configurable later
    private let defaultBufferSize: Int = 1024
    private let vertexElemSize: Int = MemoryLayout<Float>.stride * 3
    private let vertexOffset: Int = 0
    private let indexElemSize: Int = MemoryLayout<UInt32>.stride
    private let classificationElemSize: Int = MemoryLayout<UInt8>.stride
    /**
     Number of generations to keep missing anchors
     
     We can presumably keep this value high because the segmentation-based filtering takes care of removing polygons that are no longer relevant.
     However, for performance reasons, we don't want to keep it too high, as the filtering function will have to go through too many anchors.
     
     TODO: Instead of having a fixed threshold, we can consider a more adaptive approach where we don't remove the anchor if it's representative transform
     is still within the camera view frustum.
     */
    private let anchorLifetimeThreshold: Int = 10
    
    private let device: MTLDevice
    var currentSnapshot: MeshGPUSnapshot?
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func reset() {
        currentSnapshot = nil
    }
    
    func buffers(for anchorId: UUID) -> MeshGPUAnchor? {
        return currentSnapshot?.anchors[anchorId]
    }
    
    func snapshotAnchors(_ anchors: [ARAnchor]) throws {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        let meshAnchorIds: Set<UUID> = Set(meshAnchors.map { $0.identifier })
        var meshGPUAnchors: [UUID: MeshGPUAnchor] = [:]
        
        // First, update missing anchors from previous snapshot
        let missingAnchorIds: Set<UUID> = Set(
            currentSnapshot?.anchors.keys.filter { !meshAnchorIds.contains($0) } ?? []
        )
        for missingId in missingAnchorIds {
            guard var existingAnchor = currentSnapshot?.anchors[missingId] else {
                continue
            }
            existingAnchor.generation += 1
            guard existingAnchor.generation < anchorLifetimeThreshold else {
                print("Removing anchor \(missingId) after exceeding lifetime threshold")
                continue
            }
            meshGPUAnchors[missingId] = existingAnchor
        }
        
        // Next, add/update current anchors
        for (_, meshAnchor) in meshAnchors.enumerated() {
            let meshGPUAnchor = try createSnapshot(meshAnchor: meshAnchor)
            meshGPUAnchors[meshAnchor.identifier] = meshGPUAnchor
        }
        
        currentSnapshot = MeshGPUSnapshot(
            vertexStride: vertexElemSize, vertexOffset: vertexOffset,
            indexStride: indexElemSize,
            classificationStride: classificationElemSize,
            anchors: meshGPUAnchors
        )
    }
    
    func removeAnchors(_ anchors: [ARAnchor]) {
        let meshAnchors = anchors.compactMap { $0 as? ARMeshAnchor }
        var meshGPUAnchors = currentSnapshot?.anchors ?? [:]
        for (_, meshAnchor) in meshAnchors.enumerated() {
            meshGPUAnchors.removeValue(forKey: meshAnchor.identifier)
        }
        currentSnapshot = MeshGPUSnapshot(
            vertexStride: vertexElemSize, vertexOffset: vertexOffset,
            indexStride: indexElemSize,
            classificationStride: classificationElemSize,
            anchors: meshGPUAnchors
        )
    }
    
    /**
    Create or update the GPU snapshot for the given ARMeshAnchor
     
     TODO: Check possibility of blitting directly to MTLBuffer using a blit command encoder for better performance
     */
    func createSnapshot(meshAnchor: ARMeshAnchor) throws -> MeshGPUAnchor {
        let geometry = meshAnchor.geometry
        let vertices = geometry.vertices               // ARGeometrySource (format .float3)
        let faces = geometry.faces                  // ARGeometryElement
        let classifications = geometry.classification
        let anchorTransform = meshAnchor.transform
        
        var meshGPUAnchor: MeshGPUAnchor = try currentSnapshot?.anchors[meshAnchor.identifier] ?? {
            let vertexBuffer = try MeshBufferUtils.makeBuffer(device: device, length: defaultBufferSize, options: .storageModeShared)
            let indexBuffer = try MeshBufferUtils.makeBuffer(device: device, length: defaultBufferSize, options: .storageModeShared)
            return MeshGPUAnchor(
                vertexBuffer: vertexBuffer, indexBuffer: indexBuffer, classificationBuffer: nil, anchorTransform: anchorTransform
            )
        }()
        
        // Assign vertex buffer
        // MARK: This code assumes the vertex format will always be only Float3
        let vertexElemSize = MemoryLayout<Float>.stride * 3
        let vertexByteCount = vertices.count * vertexElemSize
        try MeshBufferUtils.ensureCapacity(device: device, buf: &meshGPUAnchor.vertexBuffer, requiredBytes: vertexByteCount)
        
        let vertexSrcPtr = vertices.buffer.contents().advanced(by: vertices.offset)
        if (vertices.stride == vertexElemSize) {
            try MeshBufferUtils.copyContiguous(srcPtr: vertexSrcPtr, dst: meshGPUAnchor.vertexBuffer, byteCount: vertexByteCount)
        } else {
            try MeshBufferUtils.copyStrided(count: vertices.count, srcPtr: vertexSrcPtr, srcStride: vertices.stride,
                            dst: meshGPUAnchor.vertexBuffer, elemSize: vertexElemSize)
        }
        
        // Assign index buffer
        // MARK: This code assumes the index type will always be only UInt32
        let indexTypeSize = MemoryLayout<UInt32>.stride
        let indexByteCount = faces.count * faces.bytesPerIndex * faces.indexCountPerPrimitive
        try MeshBufferUtils.ensureCapacity(device: device, buf: &meshGPUAnchor.indexBuffer, requiredBytes: indexByteCount)
        
        let indexSrcPtr = faces.buffer.contents()
        if (faces.bytesPerIndex == indexTypeSize) {
            try MeshBufferUtils.copyContiguous(srcPtr: indexSrcPtr, dst: meshGPUAnchor.indexBuffer, byteCount: indexByteCount)
        } else {
            try MeshBufferUtils.copyStrided(count: faces.count * faces.indexCountPerPrimitive, srcPtr: indexSrcPtr, srcStride: faces.bytesPerIndex,
                            dst: meshGPUAnchor.indexBuffer, elemSize: indexTypeSize)
        }
        
        // Assign classification buffer (if available)
        if let classifications = classifications {
            // MARK: This code assumes the classification type will always be only UInt8
            let classificationElemSize = MemoryLayout<UInt8>.stride
            let classificationByteCount = classifications.count * classificationElemSize
            if meshGPUAnchor.classificationBuffer == nil {
                let newCapacity = MeshBufferUtils.nextCap(classificationByteCount)
                meshGPUAnchor.classificationBuffer = try MeshBufferUtils.makeBuffer(device: device, length: newCapacity, options: .storageModeShared)
            } else {
                try MeshBufferUtils.ensureCapacity(device: device, buf: &meshGPUAnchor.classificationBuffer!, requiredBytes: classificationByteCount)
            }
            let classificationSrcPtr = classifications.buffer.contents().advanced(by: classifications.offset)
            if (classifications.stride == classificationElemSize) {
                try MeshBufferUtils.copyContiguous(
                    srcPtr: classificationSrcPtr, dst: meshGPUAnchor.classificationBuffer!, byteCount: classificationByteCount
                )
            } else {
                try MeshBufferUtils.copyStrided(
                    count: classifications.count, srcPtr: classificationSrcPtr, srcStride: classifications.stride,
                    dst: meshGPUAnchor.classificationBuffer!, elemSize: classificationElemSize)
            }
        } else {
            meshGPUAnchor.classificationBuffer = nil
        }
        
        meshGPUAnchor.vertexCount = vertices.count
        meshGPUAnchor.indexCount = faces.count * faces.indexCountPerPrimitive
        meshGPUAnchor.faceCount = faces.count
        meshGPUAnchor.generation += 1
        return meshGPUAnchor
    }
}
