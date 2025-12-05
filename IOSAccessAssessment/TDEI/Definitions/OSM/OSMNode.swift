//
//  OSMNode.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/2/25.
//

struct OSMNode: OSMElement {
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
