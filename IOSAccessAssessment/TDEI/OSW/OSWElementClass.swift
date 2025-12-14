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
        This is a definition for an analysis-oriented node. It is not directly supported by OSW schema.
     */
    case AppNode
    
    struct IdentifyingField: Sendable {
        let field: OSWField
        let value: String
    }
    
    struct Metadata: Sendable {
        let description: String
        let parent: OSWElementClass?
        let geometry: OSWGeometry
        let identifyingFields: [IdentifyingField]
        
        init(
            description: String,
            parent: OSWElementClass? = nil,
            geometry: OSWGeometry,
            identifyingFields: [IdentifyingField] = []
        ) {
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
                description: "A special case of an abstract Node.",
                parent: nil,
                geometry: .point
            )
        case .Footway:
            return Metadata(
                description: "The centerline of a dedicated pedestrian path that does not fall into any other subcategories.",
                parent: nil,
                geometry: .linestring,
                identifyingFields: [
                    IdentifyingField(field: .highway, value: "footway")
                ]
            )
        case .Sidewalk:
            return Metadata(
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
                description: "Pole",
                parent: nil,
                geometry: .point,
                identifyingFields: [
                    IdentifyingField(field: .man_made, value: "utility_pole")
                ]
             )
        case .TrafficLight:
            return Metadata(
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
                description: "Traffic Sign",
                parent: nil,
                geometry: .point,
                identifyingFields: [
                    IdentifyingField(field: .traffic_sign, value: "yes")
                ]
            )
        case .AppNode:
            return Metadata(
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
        return metadata.description
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
