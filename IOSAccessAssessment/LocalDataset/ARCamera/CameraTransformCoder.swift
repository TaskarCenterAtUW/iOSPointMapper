//
//  TransformEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

import Foundation

enum CameraTransformCoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    case fileNotFound
    case fileReadFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create camera transform file."
        case .dataWriteFailed:
            return "Failed to write data to camera transform file."
        case .fileNotFound:
            return "Camera transform file not found."
        case .fileReadFailed:
            return "Failed to read camera transform file."
        }
    }
}

class CameraTransformEncoder {
    private let path: URL
    let fileHandle: FileHandle
    
    init(url: URL) throws {
        self.path = url
        try "".write(to: self.path, atomically: true, encoding: .utf8)
        self.fileHandle = try FileHandle(forWritingTo: self.path)
        guard let header = "timestamp, frame, rxx, rxy, rxz, ryx, ryy, ryz, rzx, rzy, rzz, x, y, z\n".data(using: .utf8) else {
            throw CameraTransformCoderError.fileCreationFailed
        }
        try self.fileHandle.write(contentsOf: header)
    }
    
    func add(transform: simd_float4x4, timestamp: TimeInterval, frameNumber: UUID) throws {
        let rotationX = transform.columns.0
        let rotationY = transform.columns.1
        let rotationZ = transform.columns.2
        let translation = transform.columns.3
        
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(timestamp), \(frameNumber), \(rotationX.x), \(rotationX.y), \(rotationX.z), \(rotationY.x), \(rotationY.y), \(rotationY.z), \(rotationZ.x), \(rotationZ.y), \(rotationZ.z), \(translation.x), \(translation.y), \(translation.z)\n"
        guard let lineData = line.data(using: .utf8) else {
            throw CameraTransformCoderError.dataWriteFailed
        }
        try self.fileHandle.write(contentsOf: lineData)
    }
    
    func done() throws {
        try self.fileHandle.close()
    }
}

class CameraTransformDecoder {
    private let path: URL
    
    init(url: URL) {
        self.path = url
    }
    
    func load() throws -> [(timestamp: TimeInterval, frame: UUID, transform: simd_float4x4)] {
        guard FileManager.default.fileExists(atPath: self.path.absoluteString) else {
            throw CameraTransformCoderError.fileNotFound
        }
        guard let fileContents = try? String(contentsOf: self.path, encoding: .utf8) else {
            throw CameraTransformCoderError.fileReadFailed
        }
        let fileLines = fileContents.components(separatedBy: .newlines).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let expectedHeader = "timestamp, frame, rxx, rxy, rxz, ryx, ryy, ryz, rzx, rzy, rzz, x, y, z"
        guard let headerLine = fileLines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              headerLine == expectedHeader else {
            throw CameraTransformCoderError.fileReadFailed
        }
        let columnNames = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let timestampIndex = columnNames.firstIndex(of: "timestamp")
        let frameIndex = columnNames.firstIndex(of: "frame")
        let rxxIndex = columnNames.firstIndex(of: "rxx")
        let rxyIndex = columnNames.firstIndex(of: "rxy")
        let rxzIndex = columnNames.firstIndex(of: "rxz")
        let ryxIndex = columnNames.firstIndex(of: "ryx")
        let ryyIndex = columnNames.firstIndex(of: "ryy")
        let ryzIndex = columnNames.firstIndex(of: "ryz")
        let rzxIndex = columnNames.firstIndex(of: "rzx")
        let rzyIndex = columnNames.firstIndex(of: "rzy")
        let rzzIndex = columnNames.firstIndex(of: "rzz")
        let xIndex = columnNames.firstIndex(of: "x")
        let yIndex = columnNames.firstIndex(of: "y")
        let zIndex = columnNames.firstIndex(of: "z")
        guard let timestampIndex, let frameIndex, let rxxIndex, let rxyIndex, let rxzIndex, let ryxIndex, let ryyIndex, let ryzIndex, let rzxIndex, let rzyIndex, let rzzIndex, let xIndex, let yIndex, let zIndex else {
            throw CameraTransformCoderError.fileReadFailed
        }
        let maxIndex = max(timestampIndex, frameIndex, rxxIndex, rxyIndex, rxzIndex, ryxIndex, ryyIndex, ryzIndex, rzxIndex, rzyIndex, rzzIndex, xIndex, yIndex, zIndex)
        var cameraTransformDataList: [(timestamp: TimeInterval, frame: UUID, transform: simd_float4x4)] = []
        for line in fileLines.dropFirst() {
            let values = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard columnNames.count > maxIndex else {
                continue
            }
            guard let timestamp = TimeInterval(values[timestampIndex]),
                  let frame = UUID(uuidString: values[frameIndex]),
                  let rxx = Float(values[rxxIndex]),
                  let rxy = Float(values[rxyIndex]),
                  let rxz = Float(values[rxzIndex]),
                  let ryx = Float(values[ryxIndex]),
                  let ryy = Float(values[ryyIndex]),
                  let ryz = Float(values[ryzIndex]),
                  let rzx = Float(values[rzxIndex]),
                  let rzy = Float(values[rzyIndex]),
                  let rzz = Float(values[rzzIndex]),
                  let x = Float(values[xIndex]),
                  let y = Float(values[yIndex]),
                  let z = Float(values[zIndex]) else {
                continue
            }
            let transform = simd_float4x4(
                SIMD4<Float>(rxx, rxy, rxz, 0),
                SIMD4<Float>(ryx, ryy, ryz, 0),
                SIMD4<Float>(rzx, rzy, rzz, 0),
                SIMD4<Float>(x, y, z, 1)
            )
            cameraTransformDataList.append((timestamp: timestamp, frame: frame, transform: transform))
        }
        return cameraTransformDataList
    }
}
