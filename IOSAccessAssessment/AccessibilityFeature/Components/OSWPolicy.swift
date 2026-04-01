//
//  OSWPolicy.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//
import Foundation

struct OSWPolicy: Sendable, Codable, Equatable, Hashable {
    let oswElementClass: OSWElementClass
    /// Whether the element should be considered as existing by default if a nearby feature of the same class is detected.
    let isExistingFirst: Bool
}

extension OSWPolicy {
    static let `default` = OSWPolicy(oswElementClass: .BareNode, isExistingFirst: false)
}
