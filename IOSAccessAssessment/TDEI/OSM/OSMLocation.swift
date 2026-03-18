//
//  OSMLocation.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/17/26.
//

import Foundation
import CoreLocation

struct OSMLocationElement: Codable, Sendable {
    var coordinates: [CLLocationCoordinate2D]
    var isWay: Bool
    var isClosed: Bool
    
    init(coordinates: [CLLocationCoordinate2D], isWay: Bool, isClosed: Bool) {
        self.coordinates = coordinates
        self.isWay = isWay
        self.isClosed = isClosed
    }
    
    enum CodingKeys: String, CodingKey {
        case coordinates
        case isWay
        case isClosed
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let encodedCoordinates = coordinates.map { coordinate in
            [coordinate.latitude, coordinate.longitude]
        }
        try container.encode(encodedCoordinates, forKey: .coordinates)
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedCoordinates = try container.decode([[Double]].self, forKey: .coordinates)
        self.coordinates = try decodedCoordinates.map { coordinateArray in
            guard coordinateArray.count == 2 else {
                throw DecodingError.dataCorruptedError(
                    forKey: .coordinates,
                    in: container,
                    debugDescription: "Each coordinate must have exactly two elements: latitude and longitude."
                )
            }
            return CLLocationCoordinate2D(latitude: coordinateArray[0], longitude: coordinateArray[1])
        }
        self.isWay = try container.decode(Bool.self, forKey: .isWay)
        self.isClosed = try container.decode(Bool.self, forKey: .isClosed)
    }
}

struct OSMLocationDetails: Codable, Sendable {
    var locations: [OSMLocationElement]
    
    init(locations: [OSMLocationElement]) {
        self.locations = locations
    }
    
    enum CodingKeys: String, CodingKey {
        case locations
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(locations, forKey: .locations)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.locations = try container.decode([OSMLocationElement].self, forKey: .locations)
    }
}
