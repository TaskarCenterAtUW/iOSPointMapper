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

struct HeadingData {
    let timestamp: TimeInterval
    let magneticHeading: Double
    let trueHeading: Double
//    let headingAccuracy: Double
}

class LocationEncoder {
    let path: URL
    let fileHandle: FileHandle

    init(url: URL) throws {
        self.path = url
        FileManager.default.createFile(atPath: self.path.absoluteString,  contents:Data("".utf8), attributes: nil)
        try "".write(to: self.path, atomically: true, encoding: .utf8)
        self.fileHandle = try FileHandle(forWritingTo: self.path)
        let heading: String = "timestamp, frame, latitude, longitude\n"
//            , altitude, horizontal_accuracy, vertical_accuracy, speed, course, floor_level\n"
        self.fileHandle.write(heading.data(using: .utf8)!)
    }

    func add(locationData: LocationData, frameNumber: UUID) {
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(locationData.timestamp), \(frameNumber), \(locationData.latitude), \(locationData.longitude)\n"
//        , \(locationData.altitude), \(locationData.horizontalAccuracy), \(locationData.verticalAccuracy), \(locationData.speed), \(locationData.course), \(locationData.floorLevel)\n"
        self.fileHandle.write(line.data(using: .utf8)!)
    }

    func done() throws {
        try self.fileHandle.close()
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
        let heading: String = "timestamp, frame, magnetic_heading, true_heading\n"
//            , heading_accuracy\n"
        self.fileHandle.write(heading.data(using: .utf8)!)
    }

    func add(headingData: HeadingData, frameNumber: UUID) {
        let frameNumber = String(frameNumber.uuidString)
        let line = "\(headingData.timestamp), \(frameNumber) \(headingData.magneticHeading), \(headingData.trueHeading)\n"
//        , \(headingData.headingAccuracy)\n"
        self.fileHandle.write(line.data(using: .utf8)!)
    }

    func done() throws {
        try self.fileHandle.close()
    }
}
