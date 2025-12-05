//
//  OSMElement.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/17/25.
//

protocol OSMElement: Sendable, Equatable, Hashable {
    var id: String { get }
    var version: String { get }
    
    func toOSMCreateXML(changesetId: String) -> String
    func toOSMModifyXML(changesetId: String) -> String
    func toOSMDeleteXML(changesetId: String) -> String
}
