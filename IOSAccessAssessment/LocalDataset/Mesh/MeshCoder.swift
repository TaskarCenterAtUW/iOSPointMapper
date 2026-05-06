//
//  MeshEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 2/9/26.
//

import Foundation
import Accelerate
import ARKit
import RealityKit
import PointNMapShared

enum MeshCoderError: Error, LocalizedError {
    case modelEntityHasNoModel
    case noVertexOrIndexData
    case invalidFilePath(String)
    case invalidFileData
    case invalidMeshVertexData
    case invalidMeshIndexData
    
    var errorDescription: String? {
        switch self {
        case .modelEntityHasNoModel:
            return "ModelEntity has no model."
        case .noVertexOrIndexData:
            return "No vertex or index data found in ModelEntity."
        case .invalidFilePath(let path):
            return "Invalid file path: \(path)"
        case .invalidFileData:
            return "Invalid file data."
        case .invalidMeshVertexData:
            return "Invalid vertex data in mesh."
        case .invalidMeshIndexData:
            return "Invalid index data in mesh."
        }
    }
}

class MeshEncoder {
    private let baseDirectory: URL

    init(outDirectory: URL) throws {
        self.baseDirectory = outDirectory
        try FileManager.default.createDirectory(at: self.baseDirectory.absoluteURL, withIntermediateDirectories: true, attributes: nil)
    }
    
    func save(meshAnchors: [ARMeshAnchor], frameNumber: UUID) throws {
        let filename = String(frameNumber.uuidString)
        
        var meshContents: [MeshContents] = []
        var vertexBase: UInt32 = 0
        for anchor in meshAnchors {
            let content = getContentsForAnchor(meshAnchor: anchor, vertexColor: .white)
            /// Rebase the indices to the total vertex count so far
            let rebasedIndices = content.indices.map { $0 + vertexBase }
            vertexBase += UInt32(content.positions.count)
            let rebasedContent = MeshContents(
                positions: content.positions,
                indices: rebasedIndices,
                classifications: content.classifications,
                colorR8: content.colorR8,
                colorG8: content.colorG8,
                colorB8: content.colorB8
            )
            meshContents.append(rebasedContent)
        }
        
        let ply = generatePlyContent(meshContents, includeColor: true, includeClassification: true)
        let path = baseDirectory.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("ply")
        try ply.data(using: .utf8)?.write(to: path, options: .atomic)
    }
    
    func save(meshContents: MeshContents, frameNumber: UUID) throws {
        let filename = String(frameNumber.uuidString)
        let ply = generatePlyContent([meshContents], includeColor: true, includeClassification: meshContents.classifications != nil)
        let path = baseDirectory.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("ply")
        try ply.data(using: .utf8)?.write(to: path, options: .atomic)
    }
    
    func getContentsForAnchor(
        meshAnchor: ARMeshAnchor,
        vertexColor: UIColor = .white
    ) -> MeshContents {
        let geometry = meshAnchor.geometry
        let transform = meshAnchor.transform
        
        var r8 = 255, g8 = 255, b8 = 255
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        vertexColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        r8 = Int(r * 255)
        g8 = Int(g * 255)
        b8 = Int(b * 255)
        
        // --- Vertices (positions) ---
        let vertexCount = geometry.vertices.count
//        var positions: [SIMD3<Float>] = []
        var positions: [packed_float3] = []
        positions.reserveCapacity(vertexCount)
        
        let vertexBuffer = geometry.vertices.buffer.contents()
        let vertexStride = geometry.vertices.stride
        let vertexOffset = geometry.vertices.offset
        
        for i in 0..<vertexCount {
            let ptr = vertexBuffer.advanced(by: vertexOffset + i * vertexStride)
            let local = ptr.assumingMemoryBound(to: SIMD3<Float>.self).pointee
            let world = transform * SIMD4<Float>(local, 1.0)
//            positions.append(SIMD3(world.x, world.y, world.z))
            positions.append(packed_float3(x: world.x, y: world.y, z: world.z))
        }
        
        // --- Indices ---
        let faceCount = geometry.faces.count
        var indices: [UInt32] = []
        /// Each face is a triangle (3 indices)
        indices.reserveCapacity(faceCount * 3)
        
        let facesBuffer = geometry.faces.buffer.contents()
        let indicesPerFace = geometry.faces.indexCountPerPrimitive
        for i in 0..<faceCount {
            let baseAddress = facesBuffer.advanced(by: i * indicesPerFace * MemoryLayout<UInt32>.size)
            for offset in 0..<indicesPerFace {
                let ptr = baseAddress.advanced(by: offset * MemoryLayout<UInt32>.size).assumingMemoryBound(to: UInt32.self)
                indices.append(ptr.pointee)
            }
        }
        
        // --- Classifications (optional) ---
        let classifications = geometry.classification
        var classificationValues: [UInt8] = []
        if let classifications {
            let classificationCount = classifications.count
            
            let classificationBuffer = classifications.buffer.contents()
            
            for i in 0..<classificationCount {
                let ptr = classificationBuffer.advanced(by: i)
                let value = ptr.assumingMemoryBound(to: UInt8.self).pointee
                classificationValues.append(value)
            }
        }
        
        return MeshContents(
            positions: positions,
            indices: indices,
            classifications: classifications != nil ? classificationValues : nil,
            colorR8: r8,
            colorG8: g8,
            colorB8: b8
        )
    }
    
    func generatePlyContent(
        _ meshContents: [MeshContents],
        includeColor: Bool = true,
        includeClassification: Bool = false,
    ) -> String {
        var ply = ""
        ply += "ply\nformat ascii 1.0\n"
        ply += "comment generated by RealityKit exporter\n"
        
        let totalVertices = meshContents.reduce(0) { $0 + $1.positions.count }
        let totalFaces = meshContents.reduce(0) { $0 + ($1.indices.count / 3) }
//        print("Total Faces: \(totalFaces), Total Vertices: \(totalVertices)")
        ply += "element vertex \(totalVertices)\n"
        ply += "property float x\nproperty float y\nproperty float z\n"
        ply += "element face \(totalFaces)\nproperty list uchar int vertex_indices\n"
        if includeColor {
            ply += "property uchar red\nproperty uchar green\nproperty uchar blue\n"
        }
        if includeClassification {
            ply += "property uchar classification\n"
        }
        ply += "end_header\n"
        
        for content in meshContents {
            for pos in content.positions {
                ply += "\(pos.x) \(pos.y) \(pos.z)\n"
            }
        }
        
        for content in meshContents {
//            let faceCount = content.indices.count / 3
            for f in stride(from: 0, to: content.indices.count, by: 3) {
                let i0 = content.indices[f]
                let i1 = content.indices[f + 1]
                let i2 = content.indices[f + 2]
                var faceLine = "3 \(i0) \(i1) \(i2)"
                if includeColor {
                    faceLine += " \(content.colorR8) \(content.colorG8) \(content.colorB8)"
                }
                if includeClassification, let classifications = content.classifications,
                   f < (classifications.count * 3) {
                    let classificationIndex = f / 3
                    let classificationValue = classifications[classificationIndex]
                    faceLine += " \(classificationValue)"
                }
                faceLine += "\n"
                ply += faceLine
            }
            if content.classifications == nil && includeClassification {
                print("Warning: Classification data is missing for some content, but includeClassification is true.")
            }
        }
        
        return ply
    }
}

struct MeshContentsHeaderConfig: Sendable {
    let vertexCount: Int
    let faceCount: Int
    
    let headerEndIndex: Int
    /// Vertex
    let vertexSize: Int
    let xColIndex: Int
    let yColIndex: Int
    let zColIndex: Int
    /// Color
    let includeColor: Bool
    let redColIndex: Int
    let greenColIndex: Int
    let blueColIndex: Int
    /// Classification
    let includeClassification: Bool
    let classificationColIndex: Int
}

class MeshDecoder {
    private let baseDirectory: URL
    
    init(inDirectory: URL) {
        self.baseDirectory = inDirectory
    }
    
    /**
     Since we cannot generate ARMeshAnchors from PLY files, this function will return the raw vertex and index data contained in the PLY. The caller can then decide how to use this data (e.g. create custom mesh anchors, post-process it, etc.).
     */
    func load(frameNumber: UUID, defaultClassificationValue: Int = 0) throws -> MeshContents {
        let filename = String(frameNumber.uuidString)
        let path = self.baseDirectory.absoluteURL.appendingPathComponent(filename, isDirectory: false).appendingPathExtension("ply")
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw MeshCoderError.invalidFilePath(path.path)
        }
        guard let data = try? Data(contentsOf: path),
              let text = String(data: data, encoding: .utf8) else {
            throw MeshCoderError.invalidFileData
        }
        return try getMeshFromPlyContent(text, defaultClassificationValue: defaultClassificationValue)
    }
    
    func getMeshFromPlyContent(_ content: String, defaultClassificationValue: Int = 0) throws -> MeshContents {
        let lines = content.split(whereSeparator: \.isNewline).map { String($0) }
        let headerConfig = try parseHeader(content)
        
        /// Parse vertices
//        var positions: [SIMD3<Float>] = []
        var positions: [packed_float3] = []
        positions.reserveCapacity(headerConfig.vertexCount)
        
        let vertexStartIndex = headerConfig.headerEndIndex + 1
        let vertexEndIndex = vertexStartIndex + headerConfig.vertexCount
        for i in vertexStartIndex..<vertexEndIndex {
            let parts = lines[i].split(separator: " ")
            if parts.count >= 3, let x = Float(parts[0]), let y = Float(parts[1]), let z = Float(parts[2]) {
//                positions.append(SIMD3(x, y, z))
                positions.append(packed_float3(x: x, y: y, z: z))
            }
            else {
                throw MeshCoderError.invalidMeshVertexData
            }
        }
        
        /// Parse faces (indices)
        var faces: [UInt32] = []
        var classifications: [UInt8]? = headerConfig.includeClassification ? [] : nil
        var colorR8 = 255, colorG8 = 255, colorB8 = 255
        
        faces.reserveCapacity(headerConfig.faceCount * 3)
        if headerConfig.includeClassification {
            classifications?.reserveCapacity(headerConfig.faceCount)
        }
        
        let faceStartIndex = headerConfig.headerEndIndex + 1 + headerConfig.vertexCount
        let faceEndIndex = faceStartIndex + headerConfig.faceCount
        for i in faceStartIndex..<faceEndIndex {
            let parts = lines[i].split(separator: " ")
            if parts.count >= 4, let vertexCount = Int(parts[0]), vertexCount == 3,
               let i0 = UInt32(parts[1]), let i1 = UInt32(parts[2]), let i2 = UInt32(parts[3]) {
                faces.append(contentsOf: [i0, i1, i2])
                if headerConfig.includeClassification {
                    if headerConfig.classificationColIndex < parts.count,
                       let classificationValue = UInt8(parts[headerConfig.classificationColIndex]) {
                        classifications?.append(classificationValue)
                    } else {
                        classifications?.append(UInt8(defaultClassificationValue))
                    }
                }
                if headerConfig.includeColor {
                    if headerConfig.redColIndex != -1, headerConfig.redColIndex < parts.count,
                       let r = Int(parts[headerConfig.redColIndex]) {
                        colorR8 = r
                    }
                    if headerConfig.greenColIndex != -1, headerConfig.greenColIndex < parts.count,
                       let g = Int(parts[headerConfig.greenColIndex]) {
                        colorG8 = g
                    }
                    if headerConfig.blueColIndex != -1, headerConfig.blueColIndex < parts.count,
                       let b = Int(parts[headerConfig.blueColIndex]) {
                        colorB8 = b
                    }
                }
            }
            else {
                throw MeshCoderError.invalidMeshIndexData
            }
        }
        
//        print("Number of vertices and faces parsed: \(positions.count) vertices, \(faces.count / 3) faces")
        
        return MeshContents(
            positions: positions,
            indices: faces,
            classifications: classifications,
            colorR8: colorR8, colorG8: colorG8, colorB8: colorB8
        )
    }
    
    /**
        Parses the header of the PLY content to extract metadata like vertex count, face count, column indices for position/color/classification, etc. This information is crucial for correctly interpreting the vertex and face data in the body of the PLY file.
     
        - NOTE:
        Assumes that the vertex indices always precede color and classification properties in the file.
     */
    private func parseHeader(_ content: String) throws -> MeshContentsHeaderConfig {
        let lines = content.split(whereSeparator: \.isNewline).map { String($0) }
        
        var vertexCount = 0
        var faceCount = 0
        
        var headerEndIndex = -1
        
        var vertexSize = -1 // should be filled before color and classification parsing
        var xColIndex = -1, yColIndex = -1, zColIndex = -1
        
        var includeColor = false
        var redColIndex = -1, greenColIndex = -1, blueColIndex = -1
        var includeClassification = false
        var classificationColIndex = -1
        
        var currentFaceIndex = 0 // 0 to cover the vertex count at index 0, then incremented as we parse vertex properties. Used to assign color/classification column indices.
        
        /// Parse header
        for (i, line) in lines.enumerated() {
            if line.starts(with: "element vertex") {
                let parts = line.split(separator: " ")
                if parts.count == 3, let count = Int(parts[2]) {
                    vertexCount = count
                }
            }
            if line.starts(with: "element face") {
                let parts = line.split(separator: " ")
                if parts.count == 3, let count = Int(parts[2]) {
                    faceCount = count
                }
            }
            if line.contains("property float x") {
                vertexSize += 1
                currentFaceIndex += 1
                xColIndex = vertexSize
            }
            if line.contains("property float y") {
                vertexSize += 1
                currentFaceIndex += 1
                yColIndex = vertexSize
            }
            if line.contains("property float z") {
                vertexSize += 1
                currentFaceIndex += 1
                zColIndex = vertexSize
            }
            if line.contains("property uchar red") {
                includeColor = true
                currentFaceIndex += 1
                redColIndex = currentFaceIndex
            }
            if line.contains("property uchar green") {
                includeColor = true
                currentFaceIndex += 1
                greenColIndex = currentFaceIndex
            }
            if line.contains("property uchar blue") {
                includeColor = true
                currentFaceIndex += 1
                blueColIndex = currentFaceIndex
            }
            if line.contains("property uchar classification") {
                includeClassification = true
                currentFaceIndex += 1
                classificationColIndex = currentFaceIndex
            }
            if line == "end_header" {
                headerEndIndex = i
                break
            }
        }
        if vertexCount == 0 || faceCount == 0 || headerEndIndex == -1 {
            throw MeshCoderError.invalidFileData
        }
        
        return MeshContentsHeaderConfig(
            vertexCount: vertexCount,
            faceCount: faceCount,
            headerEndIndex: headerEndIndex,
            vertexSize: vertexSize,
            xColIndex: xColIndex,
            yColIndex: yColIndex,
            zColIndex: zColIndex,
            includeColor: includeColor,
            redColIndex: redColIndex,
            greenColIndex: greenColIndex,
            blueColIndex: blueColIndex,
            includeClassification: includeClassification,
            classificationColIndex: classificationColIndex
        )
    }
}
