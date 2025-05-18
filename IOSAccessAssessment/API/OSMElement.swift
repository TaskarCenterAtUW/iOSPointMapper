//
//  OSMElement.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/17/25.
//

protocol OSMElement {
    var id: String { get }
    var version: String { get }
    
    func toOSMCreateXML(changesetId: String) -> String
    func toOSMModifyXML(changesetId: String) -> String
    func toOSMDeleteXML(changesetId: String) -> String
}

struct NodeData: OSMElement {
    var id: String
    var version: String
    var latitude: Double
    var longitude: Double
    var tags: [String: String]
    
    init(id: String = "-1", version: String = "1", latitude: Double, longitude: Double, tags: [String: String]) {
        self.id = id
        self.version = version
        self.latitude = latitude
        self.longitude = longitude
        self.tags = tags
    }
    
    func toOSMCreateXML(changesetId: String) -> String {
        let tagElements = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        return """
        <node id="\(id)" lat="\(latitude)" lon="\(longitude)" changeset="\(changesetId)">
            \(tagElements)
        </node>
        """
    }
    
    func toOSMModifyXML(changesetId: String) -> String {
        let tagElements = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        return """
        <node id="\(id)" changeset="\(changesetId)" version="\(version)">
            \(tagElements)
        </node>
        """
    }
    
    func toOSMDeleteXML(changesetId: String) -> String {
        return """
        <node id="\(id)" changeset="\(changesetId)" version="\(version)"/>
        """
    }
}

struct WayData: OSMElement {
    var id: String
    var version: String
    var tags: [String: String]
    var nodeRefs: [String]
    
    init(id: String = "-2", version: String = "1", tags: [String: String], nodeRefs: [String]) {
        self.id = id
        self.version = version
        self.tags = tags
        self.nodeRefs = nodeRefs
    }
    
    func toOSMCreateXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let refsXML = nodeRefs.map { "<nd ref=\"\($0)\" />" }.joined(separator: "\n")
        return """
        <way id="\(id)" changeset="\(changesetId)">
            \(tagsXML)
            \(refsXML)
        </way>
        """
    }
    
    func toOSMModifyXML(changesetId: String) -> String {
        let tagsXML = tags.map { "<tag k=\"\($0)\" v=\"\($1)\" />" }.joined(separator: "\n")
        let refsXML = nodeRefs.map { "<nd ref=\"\($0)\" />" }.joined(separator: "\n")
        return """
        <way id="\(id)" version="\(version)" changeset="\(changesetId)">
            \(tagsXML)
            \(refsXML)
        </way>
        """
    }
    
    func toOSMDeleteXML(changesetId: String) -> String {
        return """
        <way id="\(id)" version="\(version)" changeset="\(changesetId)"/>
        """
    }
}
