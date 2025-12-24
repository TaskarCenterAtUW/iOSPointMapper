//
//  OSWElementClass.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//

enum OSWElementClass: String, CaseIterable, Hashable, Sendable, Codable {
    case BareNode
    case Footway
    case Sidewalk
    case Building
    /**
     - WARNING:
        This is a temporary definition for Pole. It is not directly supported by OSW schema.
     */
    case Pole
    /**
     - WARNING:
        This is a temporary definition for Traffic Light. It is not directly supported by OSW schema.
     */
    case TrafficLight
    /**
     - WARNING:
        This is a temporary definition for Traffic Sign. It is not directly supported by OSW schema.
     */
    case TrafficSign
    /**
     - WARNING:
        This is a temporary definition for Vegetation. It is not directly supported by OSW schema.
     */
    case Vegetation
    /**
     - WARNING:
        This is a definition for an analysis-oriented node. It is not directly supported by OSW schema.
     */
    case AppAnchorNode
    
    struct IdentifyingField: Sendable {
        let field: OSWField
        let value: String
    }
    
    struct Metadata: Sendable {
        let name: String
        let description: String
        let parent: OSWElementClass?
        let geometry: OSWGeometry
        let identifyingFields: [IdentifyingField]
        
        init(
            name: String,
            description: String,
            parent: OSWElementClass? = nil,
            geometry: OSWGeometry,
            identifyingFields: [IdentifyingField] = []
        ) {
            self.name = name
            self.description = description
            self.parent = parent
            self.geometry = geometry
            self.identifyingFields = identifyingFields
        }
    }
    
    var metadata: Metadata {
        switch self {
        case .BareNode:
            return Metadata(
                name: "Bare Node",
                description: "A special case of an abstract Node.",
                parent: nil,
                geometry: .point
            )
        case .Footway:
            return Metadata(
                name: "Footway",
                description: "The centerline of a dedicated pedestrian path that does not fall into any other subcategories.",
                parent: nil,
                geometry: .linestring,
                identifyingFields: [
                    IdentifyingField(field: .highway, value: "footway")
                ]
            )
        case .Sidewalk:
            return Metadata(
                name: "Sidewalk",
                description: "The centerline of a sidewalk, a designated pedestrian path to the side of a street.",
                parent: .Footway,
                geometry: .linestring,
                identifyingFields: [
                    IdentifyingField(field: .highway, value: "footway"),
                    IdentifyingField(field: .footway, value: "sidewalk")
                ]
            )
        case .Building:
            return Metadata(
                name: "Building",
                description: "This field is used to mark a given entity as a building",
                parent: nil,
                geometry: .polygon,
                identifyingFields: [
                    IdentifyingField(field: .building, value: "yes"),
                    /// Temporary hard-coding to ensure correct polygon geometry. Should later be inferred from mapped data.
                    IdentifyingField(field: .custom("Type", "type"), value: "multipolygon")
                ]
            )
        case .Pole:
            return Metadata(
                name: "Pole",
                description: "Pole",
                parent: nil,
                geometry: .point,
                identifyingFields: [
                    IdentifyingField(field: .man_made, value: "utility_pole")
                ]
             )
        case .TrafficLight:
            return Metadata(
                name: "Traffic Light",
                description: "Traffic Light",
                parent: nil,
                geometry: .point,
                identifyingFields: [
                    IdentifyingField(field: .highway, value: "traffic_signals"),
                    IdentifyingField(field: .traffic_signals, value: "signal")
                ]
            )
        case .TrafficSign:
            return Metadata(
                name: "Traffic Sign",
                description: "Traffic Sign",
                parent: nil,
                geometry: .point,
                identifyingFields: [
                    IdentifyingField(field: .traffic_sign, value: "yes")
                ]
            )
        case .Vegetation:
            return Metadata(
                name: "Vegetation",
                description: "Vegetation",
                parent: nil,
                geometry: .point,
                identifyingFields: [
                    IdentifyingField(field: .natural, value: "tree")
                ]
            )
        case .AppAnchorNode:
            return Metadata(
                name: "App Anchor Node",
                description: "A point used for iOSPointMapper-specific analysis and mapping purposes.",
                parent: nil,
                geometry: .point,
                identifyingFields: [
                    IdentifyingField(field: .custom("AppAnchor", "\(APIConstants.TagKeys.appTagPrefix):anchor"), value: "yes"),
                    IdentifyingField(field: .source, value: "survey")
                ]
            )
        }
    }
}

/**
 Additional properties for OSWElementClass
 */
extension OSWElementClass {
    var description: String {
        return metadata.name
    }
    
    var parent: OSWElementClass? {
        return metadata.parent
    }
    
    var geometry: OSWGeometry {
        return metadata.geometry
    }
    
    var identifyingFieldTags: [String: String] {
        return metadata.identifyingFields.map { identifyingField in
            return (identifyingField.field.osmTagKey, identifyingField.value)
        }.reduce(into: [:]) { partialResult, keyValuePair in
            partialResult[keyValuePair.0] = keyValuePair.1
        }
    }
}
