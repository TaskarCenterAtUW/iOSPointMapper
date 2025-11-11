//
//  CapturedMeshSnapshot.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/3/25.
//
import ARKit
import RealityKit

struct CapturedMeshAnchorSnapshot: Sendable {
    let vertexData: Data
    let indexData: Data
    
    let vertexCount: Int
    let indexCount: Int
}

struct CapturedMeshSnapshot: Sendable {
    let anchors: [AccessibilityFeatureClass: CapturedMeshAnchorSnapshot]
    
    let vertexStride: Int
    let vertexOffset: Int
    let indexStride: Int
    let classificationStride: Int
}

enum CapturedMeshSnapshotError: Error, LocalizedError {
    case invalidVertexData
    case invalidIndexData
    
    var errorDescription: String? {
        switch self {
        case .invalidVertexData:
            return "The vertex data in the segmentation mesh record invalid."
        case .invalidIndexData:
            return "The index data in the segmentation mesh record invalid."
        }
    }
}

@MainActor
final class CapturedMeshSnapshotGenerator {
    func snapshotSegmentationRecords(
        from: [AccessibilityFeatureClass: SegmentationMeshRecord],
        vertexStride: Int,
        vertexOffset: Int,
        indexStride: Int,
        classificationStride: Int
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
            classificationStride: classificationStride
        )
    }
    
    func createSnapshot(
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
