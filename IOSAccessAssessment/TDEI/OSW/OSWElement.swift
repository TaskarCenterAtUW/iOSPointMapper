//
//  OSWElement.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//
import Foundation
import CoreLocation

protocol OSWElement: Sendable {
    var elementOSMString: String { get }
    
    var id: String { get }
    var version: String { get }
    
    var oswElementClass: OSWElementClass { get }
    var attributeValues: [AccessibilityFeatureAttribute: AccessibilityFeatureAttribute.Value?] { get }
    
    func toOSMCreateXML(changesetId: String) -> String
    func toOSMModifyXML(changesetId: String) -> String
    func toOSMDeleteXML(changesetId: String) -> String
}
