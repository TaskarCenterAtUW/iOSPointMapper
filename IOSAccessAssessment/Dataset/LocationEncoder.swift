//
//  LocationEncoder.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 7/4/25.
//

struct LocationData {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let speed: Double
    let course: Double
    let floorLevel: Int
}

struct HeadingData {
    let timestamp: Date
    let magneticHeading: Double
    let trueHeading: Double
    let headingAccuracy: Double
}

class LocationEncoder {
    let path: URL
    let fileHandle: FileHandle

    init(url: URL) {
        self.path = url
        FileManager.default.createFile(atPath: self.path.absoluteString,  contents:Data("".utf8), attributes: nil)
        do {
            try "".write(to: self.path, atomically: true, encoding: .utf8)
            self.fileHandle = try FileHandle(forWritingTo: self.path)
            let heading: String = "timestamp, latitude, longitude, altitude, horizontal_accuracy, vertical_accuracy, speed, course, floor_level\n"
            self.fileHandle.write(heading.data(using: .utf8)!)
        } catch let error {
            print("Can't create file \(self.path.absoluteString). \(error.localizedDescription)")
            preconditionFailure("Can't open imu file for writing.")
        }
    }

    func add(locationData: LocationData) {
        let line = "\(locationData.timestamp.timeIntervalSince1970), \(locationData.latitude), \(locationData.longitude), \(locationData.altitude), \(locationData.horizontalAccuracy), \(locationData.verticalAccuracy), \(locationData.speed), \(locationData.course), \(locationData.floorLevel)\n"
        self.fileHandle.write(line.data(using: .utf8)!)
    }

    func done() {
        do {
            try self.fileHandle.close()
        } catch let error {
            print("Closing imu \(self.path.absoluteString) file handle failed. \(error.localizedDescription)")
        }
    }
}

class HeadingEncoder {
    let path: URL
    let fileHandle: FileHandle

    init(url: URL) {
        self.path = url
        FileManager.default.createFile(atPath: self.path.absoluteString,  contents:Data("".utf8), attributes: nil)
        do {
            try "".write(to: self.path, atomically: true, encoding: .utf8)
            self.fileHandle = try FileHandle(forWritingTo: self.path)
            let heading: String = "timestamp, magnetic_heading, true_heading, heading_accuracy\n"
            self.fileHandle.write(heading.data(using: .utf8)!)
        } catch let error {
            print("Can't create file \(self.path.absoluteString). \(error.localizedDescription)")
            preconditionFailure("Can't open imu file for writing.")
        }
    }

    func add(headingData: HeadingData) {
        let line = "\(headingData.timestamp.timeIntervalSince1970), \(headingData.magneticHeading), \(headingData.trueHeading), \(headingData.headingAccuracy)\n"
        self.fileHandle.write(line.data(using: .utf8)!)
    }

    func done() {
        do {
            try self.fileHandle.close()
        } catch let error {
            print("Closing imu \(self.path.absoluteString) file handle failed. \(error.localizedDescription)")
        }
    }
}
