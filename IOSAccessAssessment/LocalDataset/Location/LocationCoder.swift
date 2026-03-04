//
//  LocationEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//
import Foundation

struct LocationData {
    let timestamp: TimeInterval
    let latitude: Double
    let longitude: Double
//    let altitude: Double
//    let horizontalAccuracy: Double
//    let verticalAccuracy: Double
//    let speed: Double
//    let course: Double
//    let floorLevel: Int
}

enum LocationCoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    case fileNotFound
    case fileReadFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create location data file."
        case .dataWriteFailed:
            return "Failed to write location data to file."
        case .fileNotFound:
            return "Location data file not found."
        case .fileReadFailed:
            return "Failed to read location data from file."
        }
    }
}

class LocationEncoder {
    let path: URL
    let fileHandle: FileHandle

    init(url: URL) throws {
        self.path = url
        FileManager.default.createFile(atPath: self.path.absoluteString,  contents:Data("".utf8), attributes: nil)
        try "".write(to: self.path, atomically: true, encoding: .utf8)
        self.fileHandle = try FileHandle(forWritingTo: self.path)
        guard let header = "timestamp, frame, latitude, longitude\n".data(using: .utf8) else {
            throw LocationCoderError.fileCreationFailed
        }
//            , altitude, horizontal_accuracy, vertical_accuracy, speed, course, floor_level\n"
        try self.fileHandle.write(contentsOf: header)
    }

    func add(locationData: LocationData, frameNumber: UUID) throws {
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(locationData.timestamp), \(frameNumber), \(locationData.latitude), \(locationData.longitude)\n"
//        , \(locationData.altitude), \(locationData.horizontalAccuracy), \(locationData.verticalAccuracy), \(locationData.speed), \(locationData.course), \(locationData.floorLevel)\n"
        guard let lineData = line.data(using: .utf8) else {
            throw LocationCoderError.dataWriteFailed
        }
        try self.fileHandle.write(contentsOf: lineData)
    }

    func done() throws {
        try self.fileHandle.close()
    }
}

class LocationDecoder {
    let path: URL
    let results: [LocationData]
    
    init(path: URL) throws {
        self.path = path
        self.results = try LocationDecoder.preload(path: path)
    }
    
    static func preload(path: URL) throws -> [LocationData] {
        guard FileManager.default.fileExists(atPath: path.absoluteString) else {
            throw LocationCoderError.fileNotFound
        }
        guard let fileContents = try? String(contentsOf: path, encoding: .utf8) else {
            throw LocationCoderError.fileReadFailed
        }
        let fileLines = fileContents.components(separatedBy: .newlines).filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let expectedHeader = "timestamp, frame, latitude, longitude"
        guard let headerLine = fileLines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              headerLine == expectedHeader else {
            throw LocationCoderError.fileReadFailed
        }
        let columnNames = headerLine.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let timestampIndex = columnNames.firstIndex(of: "timestamp")
        let latitudeIndex = columnNames.firstIndex(of: "latitude")
        let longitudeIndex = columnNames.firstIndex(of: "longitude")
        guard let timestampIndex, let latitudeIndex, let longitudeIndex else {
            throw LocationCoderError.fileReadFailed
        }
        var locationDataList: [LocationData] = []
        for line in fileLines.dropFirst() {
            let columns = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard columns.count > max(timestampIndex, latitudeIndex, longitudeIndex) else {
                continue
            }
            if let timestamp = TimeInterval(columns[timestampIndex]),
               let latitude = Double(columns[latitudeIndex]),
               let longitude = Double(columns[longitudeIndex]) {
                let locationData = LocationData(timestamp: timestamp, latitude: latitude, longitude: longitude)
                locationDataList.append(locationData)
            }
        }
        return locationDataList
    }
}
