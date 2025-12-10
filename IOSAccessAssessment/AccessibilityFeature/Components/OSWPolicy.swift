//
//  OSWPolicy.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//
import Foundation

struct OSWPolicy: Sendable, Codable, Equatable, Hashable {
    let oswElementClass: OSWElementClass
}

extension OSWPolicy {
    static let `default` = OSWPolicy(oswElementClass: .BareNode)
}
