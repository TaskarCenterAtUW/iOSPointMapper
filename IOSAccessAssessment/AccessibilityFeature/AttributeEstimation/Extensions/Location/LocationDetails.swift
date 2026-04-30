//
//  OSMLocation.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/17/26.
//

import Foundation
import CoreLocation

struct LocationElement: Codable, Sendable {
    var coordinates: [CLLocationCoordinate2D]
    /// TODO: We can add an optional `members` property to LocationElement that can hold child elements, and update the encoding/decoding logic to handle this new property appropriately. This way, we can represent the hierarchical nature of OSM data while still maintaining a clear structure for each element type.
//    var members: [LocationElement]?
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

/**
    Represents the location details of an OSM element, which can consist of multiple coordinate sets (e.g., for ways or relations).
 
 - Warning:
 This struct does not represent relation-type OSM elements properly, because it does not account for the fact that relations can contain multiple members, each of which can be a node, way, or another relation. Properly representing relations would require a more complex structure that can capture the hierarchical nature of OSM data.
 This support was not implemented because the OSW schema does not support relations.
 
- TODO:
 For relation support: we can treat LocationDetails as a tree of LocationElement structs, where each LocationElement can either have a set of coordinates (for nodes and ways) or a set of child OSMLocationElements (for relations). This way, we can represent the hierarchical nature of OSM data while still maintaining a clear structure for each element type. This will be an easier modification because we can simply add an optional `members` property to LocationElement that can hold child elements, and update the encoding/decoding logic to handle this new property appropriately.
 However, this will need modification to caller code that constructs/uses/modifies LocationDetails, because they will need to account for the possibility of nested members when working with OSM data.
 */
public struct LocationDetails: Codable, Sendable {
    var locations: [LocationElement]
    
    init(locations: [LocationElement]) {
        self.locations = locations
    }
    
    enum CodingKeys: String, CodingKey {
        case locations
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(locations, forKey: .locations)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.locations = try container.decode([LocationElement].self, forKey: .locations)
    }
}
