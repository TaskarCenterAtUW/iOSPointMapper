//
//  OSWField.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//

import Foundation

enum OSWField: CaseIterable, Sendable {
    case description
    case name
    case incline
    case length
    case width
    case barrier
    case highway
    case building
    /**
        A custom field with a user-defined name.
     */
    case custom(String, String)
    
    static var allCases: [OSWField] {
        return [
            /// TODO: Add all predefined cases here
        ]
    }
    
    /**
     Defines the type of value associated with an OSWField.
     
     - WARNING:
        This is primarily for reference and does not enforce strict type checking.
     */
    enum ValueType: Sendable {
        case boolean
        case text
        /**
         An enumeration with a predefined set of string options.
         - WARNING:
         Currently, does not perform hard validation against the options.
         */
        case enumeration(options: [String])
        case integer
        case numeric
        case opening_hours
        
        static let `default` = ValueType.text
    }
    
    struct Metadata: Sendable {
        let description: String
        let osmTagKey: String
        let valueType: ValueType
        
        init(description: String, osmTagKey: String, valueType: ValueType = .default) {
            self.description = description
            self.osmTagKey = osmTagKey
            self.valueType = valueType
        }
    }
    
    var metadata: Metadata {
        switch self {
        case .description:
            return Metadata(
                description: "A free form text field for describing the entity. This may be a field inferred from other data.",
                osmTagKey: "description"
            )
        case .name:
            return Metadata(
                description: "The (semi-)official name of an entity.",
                osmTagKey: "name"
            )
        case .incline:
            return Metadata(
                description: "The estimated incline over a particular path",
                osmTagKey: "incline",
                valueType: .numeric
            )
        case .length:
            return Metadata(
                description: "This is the calculated length of the way",
                osmTagKey: "length",
                valueType: .numeric
            )
        case .width:
            return Metadata(
                description: "The width of an Edge in meters.",
                osmTagKey: "width",
                valueType: .numeric
            )
        case .barrier:
            return Metadata(
                description: "Barrier",
                osmTagKey: "barrier",
                valueType: .enumeration(options: ["kerb", "bollard", "fence"])
            )
        case .highway:
            return Metadata(
                description: "Highway",
                osmTagKey: "highway",
                valueType: .enumeration(options: [
                    "footway", "pedestrian", "steps", "living_street", 
                    "primary", "secondary", "tertiary", "residential",
                    "service", "unclassified", "trunk", "street_lamp"
                ])
            )
        case .building:
            return Metadata(
                description: "This field is used to mark a given entity as a building",
                osmTagKey: "building",
                valueType: .enumeration(options: ["yes"])
            )
        case .custom(let fieldName, let osmTagKey):
            return Metadata(
                description: fieldName,
                osmTagKey: osmTagKey
            )
        }
    }
}

extension OSWField {
    var description: String {
        return metadata.description
    }
}
