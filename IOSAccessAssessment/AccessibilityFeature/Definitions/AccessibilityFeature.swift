//
//  AnnotatedAccessibilityFeature.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/18/25.
//
import Foundation
import CoreLocation

enum AccessibilityFeatureError: Error, LocalizedError {
    case attributeValueMismatch(attribute: AccessibilityFeatureAttribute, value: AccessibilityFeatureAttribute.Value)
    
    var errorDescription: String? {
        switch self {
        case .attributeValueMismatch(let attribute, let value):
            return "The value \(value) does not match the expected type for attribute \(attribute)."
        }
    }
}

struct LocationDetails: Codable, Sendable {
    var coordinates: [[CLLocationCoordinate2D]]
    
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinates = [[coordinate]]
    }
    
    init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = [coordinates]
    }
    
    init(coordinates: [[CLLocationCoordinate2D]]) {
        self.coordinates = coordinates
    }
    
    enum CodingKeys: String, CodingKey {
        case coordinates
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let encodedCoordinates = coordinates.map { ring in
            ring.map { coordinate in
                [coordinate.latitude, coordinate.longitude]
            }
        }
        try container.encode(encodedCoordinates, forKey: .coordinates)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedCoordinates = try container.decode([[[Double]]].self, forKey: .coordinates)
        self.coordinates = try decodedCoordinates.map { ring in
            try ring.map { coordinateArray in
                guard coordinateArray.count == 2 else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .coordinates,
                        in: container,
                        debugDescription: "Each coordinate must have exactly two elements: latitude and longitude."
                    )
                }
                return CLLocationCoordinate2D(latitude: coordinateArray[0], longitude: coordinateArray[1])
            }
        }
    }
}

protocol AccessibilityFeatureProtocol: Identifiable, Equatable {
    var id: UUID { get }
    
    var accessibilityFeatureClass: AccessibilityFeatureClass { get }
    
    var locationDetails: LocationDetails? { get set }
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] { get set }
    var experimentalAttributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] { get set }
    
    func getLastLocationCoordinate() -> CLLocationCoordinate2D?
    
    mutating func setLocationDetails(coordinates: [[CLLocationCoordinate2D]])
    
    mutating func setAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws
    mutating func setExperimentalAttributeValue(
        _ value: AccessibilityFeatureAttribute.Value,
        for attribute: AccessibilityFeatureAttribute
    ) throws
}
