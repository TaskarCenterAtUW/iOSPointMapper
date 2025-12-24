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

enum LocationEncoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create location data file."
        case .dataWriteFailed:
            return "Failed to write location data to file."
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
            throw LocationEncoderError.fileCreationFailed
        }
//            , altitude, horizontal_accuracy, vertical_accuracy, speed, course, floor_level\n"
        try self.fileHandle.write(contentsOf: header)
    }

    func add(locationData: LocationData, frameNumber: UUID) throws {
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(locationData.timestamp), \(frameNumber), \(locationData.latitude), \(locationData.longitude)\n"
//        , \(locationData.altitude), \(locationData.horizontalAccuracy), \(locationData.verticalAccuracy), \(locationData.speed), \(locationData.course), \(locationData.floorLevel)\n"
        guard let lineData = line.data(using: .utf8) else {
            throw LocationEncoderError.dataWriteFailed
        }
        try self.fileHandle.write(contentsOf: lineData)
    }

    func done() throws {
        try self.fileHandle.close()
    }
}

struct HeadingData {
    let timestamp: TimeInterval
    let magneticHeading: Double
    let trueHeading: Double
//    let headingAccuracy: Double
}

enum HeadingEncoderError: Error, LocalizedError {
    case fileCreationFailed
    case dataWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .fileCreationFailed:
            return "Unable to create heading data file."
        case .dataWriteFailed:
            return "Failed to write heading data to file."
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
            throw HeadingEncoderError.fileCreationFailed
        }
//            , heading_accuracy\n"
        try self.fileHandle.write(contentsOf: header)
    }

    func add(headingData: HeadingData, frameNumber: UUID) throws {
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(headingData.timestamp), \(frameNumber) \(headingData.magneticHeading), \(headingData.trueHeading)\n"
//        , \(headingData.headingAccuracy)\n"
        guard let lineData = line.data(using: .utf8) else {
            throw HeadingEncoderError.dataWriteFailed
        }
        try self.fileHandle.write(contentsOf: lineData)
    }

    func done() throws {
        try self.fileHandle.close()
    }
}
