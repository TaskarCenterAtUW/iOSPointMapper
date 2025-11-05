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

struct ModelEntityResource {
    let triangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]
    let color: UIColor
    let name: String
}

struct SegmentationMeshPipelineResults {
    let classModelEntityResources: [Int: ModelEntityResource]
}

/**
 A class to generate 3D mesh models from segmentation data to help integrate them into an AR scene.
 */
final class SegmentationMeshPipeline: ObservableObject {
    private var isProcessing = false
    private var currentTask: Task<SegmentationMeshPipelineResults, Error>?
    private var timeoutInSeconds: Double = 1.0
    
    private var selectionClasses: [Int] = []
    private var selectionClassLabels: [UInt8] = []
    private var selectionClassGrayscaleValues: [Float] = []
    private var selectionClassColors: [CIColor] = []
    private var selectionClassNames: [String] = []
    private var selectionClassMeshClassifications: [[ARMeshClassification]?] = []
    private var selectionClassLabelToIndexMap: [UInt8: Int] = [:]
    
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
            
            let results = try await self.processMeshAnchorsWithTimeout(with: anchors, segmentationImage: segmentationImage,
                cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics)
            try Task.checkCancellation()
            return results
        }
        
        self.currentTask = newTask
        return try await newTask.value
    }
    
    private func processMeshAnchorsWithTimeout(
        with anchors: [ARAnchor], segmentationImage: CIImage,
        cameraTransform: simd_float4x4, cameraIntrinsics: simd_float3x3
    ) async throws -> SegmentationMeshPipelineResults {
        try await withThrowingTaskGroup(of: SegmentationMeshPipelineResults.self) { group in
            group.addTask {
                return try self.processMeshAnchors(
                    with: anchors, segmentationImage: segmentationImage,
                    cameraTransform: cameraTransform, cameraIntrinsics: cameraIntrinsics)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(self.timeoutInSeconds))
                throw SegmentationMeshPipelineError.unexpectedError
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
        
        var triangleArrays: [[(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)]] = self.selectionClasses.map { _ in [] }
        var triangleNormalArrays: [[SIMD3<Float>]] = self.selectionClasses.map { _ in [] }
        
        let viewTransform = simd_inverse(cameraTransform)
        
        // Iterate through each mesh anchor and process its geometry
        for (_, meshAnchor) in meshAnchors.enumerated() {
            let geometry = meshAnchor.geometry
            let transform = meshAnchor.transform
            
            let faces = geometry.faces
            let classifications = geometry.classification
            let vertices = geometry.vertices
            
            guard let classifications = classifications else {
                continue
            }
            // Wrap in autoreleasepool to manage memory for large meshes
            for index in 0..<faces.count {
                let face = faces[index]
                let classification = getClassification(at: Int(index), classifications: classifications)
                
                let faceVertices = face.map { getVertex(at: Int($0), vertices: vertices) }
                let worldVertices = faceVertices.map { getWorldVertex(vertex: $0, anchorTransform: transform) }
                
                let worldCentroid = (worldVertices[0] + worldVertices[1] + worldVertices[2]) / 3.0
                guard let pixelPoint = projectWorldToPixel(
                    worldCentroid, viewTransform: viewTransform, intrinsics: cameraIntrinsics,
                    imageSize: CGSize(width: width, height: height)) else {
                    continue
                }
                if (index == 0) {
                    print("First face vertex: \(faceVertices[0]), First World vertex: \(worldVertices[0]), Pixel Point: \(pixelPoint)")
                    let worldVertex4D   = simd_float4(worldCentroid, 1.0)
                    let cameraVertex   = viewTransform * worldVertex4D
                    print("View Transform: \(viewTransform), Camera Vertex: \(cameraVertex)\n")
                }
                guard let segmentationValue = sampleSegmentationImage(
                    segmentationPixelBuffer, at: pixelPoint,
                    width: width, height: height, bytesPerRow: bpr) else {
                    continue
                }
                guard let segmentationClassIndex = self.selectionClassLabelToIndexMap[segmentationValue] else {
                    continue
                }
                let meshClassifications = self.selectionClassMeshClassifications[segmentationClassIndex]
                guard meshClassifications == nil || meshClassifications!.contains(classification) else {
                    continue
                }
                let edge1 = worldVertices[1] - worldVertices[0]
                let edge2 = worldVertices[2] - worldVertices[0]
                let normal = normalize(cross(edge1, edge2))
                
                triangleArrays[segmentationClassIndex].append((worldVertices[0], worldVertices[1], worldVertices[2]))
                triangleNormalArrays[segmentationClassIndex].append(normal)
            }
            
            try Task.checkCancellation()
        }
        
        var classModelEntityResources: [Int: ModelEntityResource] = [:]
        for index in 0..<self.selectionClasses.count {
            let triangles = triangleArrays[index]
            guard !triangles.isEmpty else {
                continue
            }
            let color = UIColor(ciColor: self.selectionClassColors[index])
            let name = self.selectionClassNames[index]
            let modelEntityResource: ModelEntityResource = ModelEntityResource(
                triangles: triangles,
                color: color,
                name: name
            )
            classModelEntityResources[self.selectionClasses[index]] = modelEntityResource
        }
        
        return SegmentationMeshPipelineResults(classModelEntityResources: classModelEntityResources)
    }
}

/**
 Helper methods to retrieve mesh-related data.
 
 NOTE: It may be prudent to move these to a separate utility file, or add these as extensions to ARMeshGeometry.
 */
extension SegmentationMeshPipeline {
    private func getClassification(at faceIndex: Int, classifications: ARGeometrySource) -> ARMeshClassification {
        let classificationAddress = classifications.buffer.contents().advanced(by: classifications.offset + (classifications.stride * Int(faceIndex)))
        let classificationValue = Int(classificationAddress.assumingMemoryBound(to: UInt8.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }
    
    private func getVertex(at vertexIndex: Int, vertices: ARGeometrySource) -> SIMD3<Float> {
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(vertexIndex)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
}

/**
 Helper methods to process 3D points, polygons and segmentation data.
 */
extension SegmentationMeshPipeline {
    private func getWorldVertex(vertex: SIMD3<Float>, anchorTransform: simd_float4x4) -> SIMD3<Float> {
        let worldVertex4D = (anchorTransform * SIMD4(vertex.x, vertex.y, vertex.z, 1.0))
        return SIMD3(worldVertex4D.x, worldVertex4D.y, worldVertex4D.z)
    }
    
    private func projectWorldToPixel(_ worldVertex: simd_float3,
                             viewTransform: simd_float4x4, // ARCamera.transform (camera->world)
                             intrinsics K: simd_float3x3,
                             imageSize: CGSize) -> CGPoint? {
        // world -> camera
        let worldVertex4D   = simd_float4(worldVertex, 1.0)
        let cameraVertex   = viewTransform * worldVertex4D                                  // camera space
        let x = cameraVertex.x, y = cameraVertex.y, z = cameraVertex.z
        
        // behind camera
        guard z < 0 else {
            return nil
        }
        
        // normalized image plane coords (flip Y so +Y goes up in pixels)
        let xn = x / -z
        let yn = -y / -z
        
        // intrinsics (column-major)
        let fx = K.columns.0.x
        let fy = K.columns.1.y
        let cx = K.columns.2.x
        let cy = K.columns.2.y
        
        // pixels in sensor/native image coordinates
        let u = fx * xn + cx
        let v = fy * yn + cy
        
        if u.isFinite && v.isFinite &&
            u >= 0 && v >= 0 &&
            u < Float(imageSize.width) && v < Float(imageSize.height) {
            return CGPoint(x: CGFloat(u.rounded()), y: CGFloat(v.rounded()))
        }
        return nil
    }
    
    private func sampleSegmentationImage(
        _ pixelBuffer: CVPixelBuffer, at pixel: CGPoint,
        width: Int, height: Int, bytesPerRow: Int
    ) -> UInt8? {
        let ix = Int(pixel.x), iy = Int(pixel.y)
        guard ix >= 0, iy >= 0, ix < width, iy < height else {
            return nil
        }

        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let value = ptr[iy * bytesPerRow + ix]
        return value
    }
}
