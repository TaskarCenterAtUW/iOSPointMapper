//
//  CameraIntrinsicsEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/23/25.
//

import Foundation

enum CameraIntrinsicsCoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    case fileNotFound
    case fileReadFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create camera intrinsics file."
        case .dataWriteFailed:
            return "Failed to write data to camera intrinsics file."
        case .fileNotFound:
            return "Camera intrinsics file not found."
        case .fileReadFailed:
            return "Failed to read camera intrinsics file."
        }
    }
}

class CameraIntrinsicsEncoder {
    private let path: URL
    let fileHandle: FileHandle
    
    init(url: URL) throws {
        self.path = url
        try "".write(to: self.path, atomically: true, encoding: .utf8)
        self.fileHandle = try FileHandle(forWritingTo: self.path)
        guard let header = "timestamp, frame, fx, sx, cx, sy, fy, cy, i02, i12, i22\n".data(using: .utf8) else {
            throw CameraIntrinsicsCoderError.fileCreationFailed
        }
        try self.fileHandle.write(contentsOf: header)
    }
    
    func add(intrinsics: simd_float3x3, timestamp: TimeInterval, frameNumber: UUID) throws {
        let fx = intrinsics[0,0]
        let sx = intrinsics[1,0]
        let cx = intrinsics[2,0]
        let sy = intrinsics[0,1]
        let fy = intrinsics[1,1]
        let cy = intrinsics[2,1]
        let i02 = intrinsics[0,2]
        let i12 = intrinsics[1,2]
        let i22 = intrinsics[2,2]
        
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(timestamp), \(frameNumber), \(fx), \(sx), \(cx), \(sy), \(fy), \(cy), \(i02), \(i12), \(i22)\n"
        guard let lineData = line.data(using: .utf8) else {
            throw CameraIntrinsicsCoderError.dataWriteFailed
        }
        try self.fileHandle.write(contentsOf: lineData)
    }
    
    func done() throws {
        try self.fileHandle.close()
    }
}

class CameraIntrinsicsDecoder {
    private let path: URL
    let results: [(timestamp: TimeInterval, frame: UUID, intrinsics: simd_float3x3)]
    
    init(path: URL) throws {
        self.path = path
        self.results = try CameraIntrinsicsDecoder.preload(path: path)
    }
    
    static func preload(path: URL) throws -> [(timestamp: TimeInterval, frame: UUID, intrinsics: simd_float3x3)] {
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw CameraIntrinsicsCoderError.fileNotFound
        }
        guard let fileContents = try? String(contentsOf: path, encoding: .utf8) else {
            throw CameraIntrinsicsCoderError.fileReadFailed
        }
        let fileLines = fileContents.components(separatedBy: .newlines).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let expectedHeader = "timestamp, frame, fx, sx, cx, sy, fy, cy, i02, i12, i22"
        guard let headerLine = fileLines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              headerLine == expectedHeader else {
            throw CameraIntrinsicsCoderError.fileReadFailed
        }
        let columnNames = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let timestampIndex = columnNames.firstIndex(of: "timestamp")
        let frameIndex = columnNames.firstIndex(of: "frame")
        let fxIndex = columnNames.firstIndex(of: "fx")
        let sxIndex = columnNames.firstIndex(of: "sx")
        let cxIndex = columnNames.firstIndex(of: "cx")
        let syIndex = columnNames.firstIndex(of: "sy")
        let fyIndex = columnNames.firstIndex(of: "fy")
        let cyIndex = columnNames.firstIndex(of: "cy")
        let i02Index = columnNames.firstIndex(of: "i02")
        let i12Index = columnNames.firstIndex(of: "i12")
        let i22Index = columnNames.firstIndex(of: "i22")
        guard let timestampIndex, let frameIndex, let fxIndex, let sxIndex, let cxIndex, let syIndex,
              let fyIndex, let cyIndex, let i02Index, let i12Index, let i22Index else {
            throw CameraIntrinsicsCoderError.fileReadFailed
        }
        let maxIndex = max(timestampIndex, frameIndex, fxIndex, sxIndex, cxIndex, syIndex, fyIndex, cyIndex, i02Index, i12Index, i22Index)
        var cameraIntrinsicsDataList: [(timestamp: TimeInterval, frame: UUID, intrinsics: simd_float3x3)] = []
        for line in fileLines.dropFirst() {
            let values = line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard columnNames.count > maxIndex else {
                continue
            }
            guard let timestamp = TimeInterval(values[timestampIndex]),
                  let frameNumber = UUID(uuidString: values[frameIndex]),
                  let fx = Float(values[fxIndex]),
                  let sx = Float(values[sxIndex]),
                  let cx = Float(values[cxIndex]),
                  let sy = Float(values[syIndex]),
                  let fy = Float(values[fyIndex]),
                  let cy = Float(values[cyIndex]),
                  let i02 = Float(values[i02Index]),
                  let i12 = Float(values[i12Index]),
                  let i22 = Float(values[i22Index]) else {
                continue
            }
            let intrinsics = simd_float3x3(rows: [
                SIMD3<Float>(fx, sy, i02),
                SIMD3<Float>(sx, fy, i12),
                SIMD3<Float>(cx, cy, i22)
            ])
            cameraIntrinsicsDataList.append((timestamp: timestamp, frame: frameNumber, intrinsics: intrinsics))
        }
        return cameraIntrinsicsDataList
    }
    
    /**
        Loads camera intrinsics data from a specific index, that should match the frame number.
     */
    func load(index: Int, frameNumber: UUID) -> (timestamp: TimeInterval, frame: UUID, intrinsics: simd_float3x3)? {
        guard index < results.count else { return nil }
        let cameraIntrinsicsData = results[index]
        guard cameraIntrinsicsData.frame == frameNumber else { return nil }
        return cameraIntrinsicsData
    }
}
