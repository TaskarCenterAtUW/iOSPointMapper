//
//  CapturedMeshSnapshot.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//
import ARKit
import RealityKit
import PointNMapShaderTypes

public enum CapturedMeshSnapshotError: Error, LocalizedError {
    case invalidMeshData
    case invalidVertexData
    case invalidIndexData
    case meshClassNotFound(AccessibilityFeatureClass)
    
    public var errorDescription: String? {
        switch self {
        case .invalidMeshData:
            return "The mesh data in the segmentation mesh record is invalid"
        case .invalidVertexData:
            return "The vertex data in the segmentation mesh record is invalid."
        case .invalidIndexData:
            return "The index data in the segmentation mesh record is invalid."
        case .meshClassNotFound(let featureClass):
            return "No mesh found for the accessibility feature class: \(featureClass.name)."
        }
    }
}

@MainActor
public final class CapturedMeshSnapshotGenerator {
    public init() { }
    
    public func snapshotSegmentationRecords(
        from: [AccessibilityFeatureClass: SegmentationMeshRecord],
        vertexStride: Int,
        vertexOffset: Int,
        indexStride: Int,
        classificationStride: Int,
        totalVertexCount: Int
    ) -> CapturedMeshSnapshot {
        var anchorSnapshots: [AccessibilityFeatureClass: CapturedMeshAnchorSnapshot] = [:]
        for (featureClass, segmentationRecord) in from {
            do {
                let anchorSnapshot = try createSnapshot(segmentationRecord: segmentationRecord)
                anchorSnapshots[featureClass] = anchorSnapshot
            } catch {
                print("Error creating snapshot for feature class \(featureClass): \(error.localizedDescription)")
            }
        }
        return CapturedMeshSnapshot(
            anchors: anchorSnapshots,
            vertexStride: vertexStride,
            vertexOffset: vertexOffset,
            indexStride: indexStride,
            classificationStride: classificationStride,
            totalVertexCount: totalVertexCount
        )
    }
    
    public func createSnapshot(
        segmentationRecord: SegmentationMeshRecord
    ) throws -> CapturedMeshAnchorSnapshot {
        let lowLevelMesh = segmentationRecord.mesh
        guard let vertexData = getVertexData(from: lowLevelMesh) else {
            throw CapturedMeshSnapshotError.invalidVertexData
        }
        guard let indexData = getIndexData(from: lowLevelMesh) else {
            throw CapturedMeshSnapshotError.invalidIndexData
        }
        
        return CapturedMeshAnchorSnapshot(
            vertexData: vertexData,
            indexData: indexData,
            vertexCount: segmentationRecord.vertexCount,
            indexCount: segmentationRecord.indexCount
        )
    }
    
    private func getVertexData(from mesh: LowLevelMesh) -> Data? {
        var vertexData: Data?
        mesh.withUnsafeBytes(bufferIndex: 0) { ptr in
            guard let baseAddress = ptr.baseAddress else {
                return
            }
            vertexData = Data(bytes: baseAddress, count: ptr.count)
        }
        return vertexData
    }
    
    private func getIndexData(from mesh: LowLevelMesh) -> Data? {
        var indexData: Data?
        mesh.withUnsafeIndices { ptr in
            guard let baseAddress = ptr.baseAddress else {
                return
            }
            indexData = Data(bytes: baseAddress, count: ptr.count)
        }
        return indexData
    }
}

/**
    Helper class for CapturedMeshSnapshot related operations.
    Can be used for processing the mesh snapshot, even outside the main actor.
 */
public final class CapturedMeshSnapshotHelper {
    public init() { }
    
    /**
     TODO: Instead of simd3<Float>, use packed simd types that match the vertex format in the snapshot to avoid unnecessary conversions.
     */
    public static func readFeatureSnapshot(
        capturedMeshSnapshot: CapturedMeshSnapshot,
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> [MeshPolygon] {
//        guard let featureCapturedMeshSnapshot = capturedMeshSnapshot.anchors[accessibilityFeatureClass] else {
//            throw CapturedMeshSnapshotError.meshClassNotFound(accessibilityFeatureClass)
//        }
//        
//        let vertexStride: Int = capturedMeshSnapshot.vertexStride
//        let vertexOffset: Int = capturedMeshSnapshot.vertexOffset
//        let vertexData: Data = featureCapturedMeshSnapshot.vertexData
//        let vertexCount: Int = featureCapturedMeshSnapshot.vertexCount
//        let indexStride: Int = capturedMeshSnapshot.indexStride
//        let indexData: Data = featureCapturedMeshSnapshot.indexData
//        let indexCount: Int = featureCapturedMeshSnapshot.indexCount
//        /// The Segmentation Mesh Record from which the CapturedMeshAnchorSnapshot is created
//        /// always has the .triangle topology, which means every 3 indices form a triangle polygon.
//        ///  Hence, the vertex count should be equal to the index count, and both should be multiples of 3.
//        guard vertexCount > 0, vertexCount == indexCount else {
//            throw CapturedMeshSnapshotError.invalidMeshData
//        }
//        
//        var vertexPositions: [SIMD3<Float>] = Array(repeating: SIMD3<Float>(0,0,0), count: vertexCount)
//        try vertexData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
//            guard let baseAddress = ptr.baseAddress else {
//                throw CapturedMeshSnapshotError.invalidMeshData
//            }
//            for i in 0..<vertexCount {
//                let vertexAddress = baseAddress.advanced(by: i * vertexStride + vertexOffset)
//                let vertexPointer = vertexAddress.assumingMemoryBound(to: SIMD3<Float>.self)
//                vertexPositions[i] = vertexPointer.pointee
//            }
//        }
//        
//        var indexPositions: [UInt32] = Array(repeating: 0, count: indexCount)
//        try indexData.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
//            guard let baseAddress = ptr.baseAddress else {
//                throw CapturedMeshSnapshotError.invalidMeshData
//            }
//            for i in 0..<indexCount {
//                let indexAddress = baseAddress.advanced(by: i * indexStride)
//                let indexPointer = indexAddress.assumingMemoryBound(to: UInt32.self)
//                indexPositions[i] = indexPointer.pointee
//            }
//        }
//        
//        var polygons: [MeshPolygon] = []
//        for i in 0..<(indexCount / 3) {
//            let vi0 = Int(indexPositions[i*3])
//            let vi1 = Int(indexPositions[i*3 + 1])
//            let vi2 = Int(indexPositions[i*3 + 2])
//            
//            let polygon = MeshPolygon(
//                v0: vertexPositions[vi0],
//                v1: vertexPositions[vi1],
//                v2: vertexPositions[vi2],
//                index0: vi0, index1: vi1, index2: vi2
//            )
//            polygons.append(polygon)
//        }
//        return polygons
        return try readFeatureSnapshot(
            capturedMeshSnapshot: capturedMeshSnapshot, accessibilityFeatureClass: accessibilityFeatureClass
        ).polygons
    }
    
    public static func readFeatureSnapshot(
        capturedMeshSnapshot: CapturedMeshSnapshot,
        accessibilityFeatureClass: AccessibilityFeatureClass
    ) throws -> MeshContents {
        guard let featureCapturedMeshSnapshot = capturedMeshSnapshot.anchors[accessibilityFeatureClass] else {
            throw CapturedMeshSnapshotError.meshClassNotFound(accessibilityFeatureClass)
        }
        
        let vertexStride: Int = capturedMeshSnapshot.vertexStride
        let vertexOffset: Int = capturedMeshSnapshot.vertexOffset
        let vertexData: Data = featureCapturedMeshSnapshot.vertexData
        let vertexCount: Int = featureCapturedMeshSnapshot.vertexCount
        let indexStride: Int = capturedMeshSnapshot.indexStride
        let indexData: Data = featureCapturedMeshSnapshot.indexData
        let indexCount: Int = featureCapturedMeshSnapshot.indexCount
        /// The Segmentation Mesh Record from which the CapturedMeshAnchorSnapshot is created
        /// always has the .triangle topology, which means every 3 indices form a triangle polygon.
        ///  Hence, the vertex count should be equal to the index count, and both should be multiples of 3.
        guard vertexCount > 0, vertexCount == indexCount else {
            throw CapturedMeshSnapshotError.invalidMeshData
        }
        
        var positions: [packed_float3] = [packed_float3](repeating: packed_float3(), count: vertexCount)
//        positions.reserveCapacity(vertexCount)
        try vertexData.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else {
                throw CapturedMeshSnapshotError.invalidVertexData
            }
            if vertexStride == MemoryLayout<packed_float3>.stride {
                try positions.withUnsafeMutableBytes { posPtr in
                    guard let posBaseAddress = posPtr.baseAddress else {
                        throw CapturedMeshSnapshotError.invalidVertexData
                    }
                    let srcPtr = baseAddress.advanced(by: vertexOffset)
                    posBaseAddress.copyMemory(from: srcPtr, byteCount: vertexCount * vertexStride)
                }
            } else {
                for i in 0..<vertexCount {
                    let vertexAddress = baseAddress.advanced(by: i * vertexStride + vertexOffset)
                    let vertexPointer = vertexAddress.assumingMemoryBound(to: packed_float3.self)
//                    positions.append(vertexPointer.pointee)
                    positions[i] = vertexPointer.pointee
                }
            }
        }
        
        var indices: [UInt32] = [UInt32](repeating: 0, count: indexCount)
//        indices.reserveCapacity(indexCount)
        try indexData.withUnsafeBytes { ptr in
            guard let baseAddress = ptr.baseAddress else {
                throw CapturedMeshSnapshotError.invalidIndexData
            }
            if indexStride == MemoryLayout<UInt32>.stride {
                try indices.withUnsafeMutableBytes { indexPtr in
                    guard let indexBaseAddress = indexPtr.baseAddress else {
                        throw CapturedMeshSnapshotError.invalidIndexData
                    }
                    indexBaseAddress.copyMemory(from: baseAddress, byteCount: indexCount * indexStride)
                }
            } else {
                for i in 0..<indexCount {
                    let indexAddress = baseAddress.advanced(by: i * indexStride)
                    let indexPointer = indexAddress.assumingMemoryBound(to: UInt32.self)
//                    indices.append(indexPointer.pointee)
                    indices[i] = indexPointer.pointee
                }
            }
        }
        
        let colorR8 = 255, colorG8 = 255, colorB8 = 255
        return MeshContents(
            positions: positions, indices: indices, classifications: nil,
            colorR8: colorR8, colorG8: colorG8, colorB8: colorB8
        )
    }
}
