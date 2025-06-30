//
//  Constants.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/18/25.
//

struct APIConstants {
    enum Constants {
        static let baseUrl = "https://osm.workspaces-stage.sidewalks.washington.edu/api/0.6"
        static let workspaceId = "288"
    }
    
    enum ElementKeys {
        static let node = "node"
        static let way = "way"
    }
    
    enum AttributeKeys {
        static let id = "id"
        static let oldId = "old_id"
        static let newId = "new_id"
        static let version = "version"
        static let newVersion = "new_version"
    }
    
    enum TagKeys {
        static let sessionIdKey = "demo:sessionId"
        static let captureIdKey = "demo:captureId"
        static let classKey = "demo:class"
        static let widthKey = "demo:width"
        static let depthKey = "demo:depth"
        static let calculatedWidthKey = "demo:demo:calculatedWidth"
        static let breakageKey = "demo:breakage"
    }
    
    enum OtherConstants {
        static let classLabelPlaceholder = "Unknown"
    }
}
