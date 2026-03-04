//
//  HeadingEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/23/25.
//

import Foundation

struct HeadingData {
    let timestamp: TimeInterval
    let magneticHeading: Double
    let trueHeading: Double
//    let headingAccuracy: Double
}

enum HeadingCoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    case fileNotFound
    case fileReadFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create heading data file."
        case .dataWriteFailed:
            return "Failed to write heading data to file."
        case .fileNotFound:
            return "Heading data file not found."
        case .fileReadFailed:
            return "Failed to read heading data from file."
        }
    }
}

class HeadingEncoder {
    let path: URL
    let fileHandle: FileHandle

    init(url: URL) throws {
        self.path = url
        FileManager.default.createFile(atPath: self.path.absoluteString,  contents:Data("".utf8), attributes: nil)
        try "".write(to: self.path, atomically: true, encoding: .utf8)
        self.fileHandle = try FileHandle(forWritingTo: self.path)
        guard let header = "timestamp, frame, magnetic_heading, true_heading\n".data(using: .utf8) else {
            throw HeadingCoderError.fileCreationFailed
        }
//            , heading_accuracy\n"
        try self.fileHandle.write(contentsOf: header)
    }

    func add(headingData: HeadingData, frameNumber: UUID) throws {
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(headingData.timestamp), \(frameNumber) \(headingData.magneticHeading), \(headingData.trueHeading)\n"
//        , \(headingData.headingAccuracy)\n"
        guard let lineData = line.data(using: .utf8) else {
            throw HeadingCoderError.dataWriteFailed
        }
        try self.fileHandle.write(contentsOf: lineData)
    }

    func done() throws {
        try self.fileHandle.close()
    }
}

struct HeadingOutputData {
    let timestamp: TimeInterval
    let frame: UUID
    let magneticHeading: Double
    let trueHeading: Double
}

class HeadingDecoder {
    let path: URL
    let results: [HeadingOutputData]
    
    init(url: URL) throws {
        self.path = url
        self.results = try HeadingDecoder.preload(path: url)
    }
    
    static func preload(path: URL) throws -> [HeadingOutputData] {
        guard FileManager.default.fileExists(atPath: path.absoluteString) else {
            throw HeadingCoderError.fileNotFound
        }
        guard let fileContents = try? String(contentsOf: path, encoding: .utf8) else {
            throw HeadingCoderError.fileReadFailed
        }
        let fileLines = fileContents.components(separatedBy: .newlines).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let expectedHeader = "timestamp, frame, magnetic_heading, true_heading"
        guard let headerLine = fileLines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              headerLine == expectedHeader else {
            throw HeadingCoderError.fileReadFailed
        }
        let columnNames = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let timestampIndex = columnNames.firstIndex(of: "timestamp")
        let frameIndex = columnNames.firstIndex(of: "frame")
        let magneticHeadingIndex = columnNames.firstIndex(of: "magnetic_heading")
        let trueHeadingIndex = columnNames.firstIndex(of: "true_heading")
        guard let timestampIndex, let frameIndex, let magneticHeadingIndex, let trueHeadingIndex else {
            throw LocationCoderError.fileReadFailed
        }
        let maxIndex = max(timestampIndex, frameIndex, magneticHeadingIndex, trueHeadingIndex)
        var headingDataList: [HeadingOutputData] = []
        for line in fileLines.dropFirst() {
            let columns = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard columns.count > maxIndex else {
                continue
            }
            if let timestamp = TimeInterval(columns[timestampIndex]),
               let frameNumber = UUID(uuidString: columns[frameIndex]),
               let magneticHeading = Double(columns[magneticHeadingIndex]),
               let trueHeading = Double(columns[trueHeadingIndex]) {
                let headingData = HeadingOutputData(
                    timestamp: timestamp, frame: frameNumber,
                    magneticHeading: magneticHeading, trueHeading: trueHeading
                )
                headingDataList.append(headingData)
            }
        }
        return headingDataList
    }
    
    /**
        Loads heading data from a specific index, that should match the frame number.
     */
    func load(index: Int, frameNumber: UUID) -> HeadingOutputData? {
        guard index < results.count else { return nil }
        let headingData = results[index]
        guard headingData.frame == frameNumber else { return nil }
        return headingData
    }
}
