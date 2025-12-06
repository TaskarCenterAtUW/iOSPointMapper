//
//  OSMWay.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/2/25.
//

struct OSMWay: OSMElement {
    let id: String
    let version: String
    let tags: [String: String]
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
