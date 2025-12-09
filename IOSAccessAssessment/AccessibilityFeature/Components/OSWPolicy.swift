//
//  OSWPolicy.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//

struct OSWPolicy: Sendable, Codable, Equatable, Hashable {
    let oswElement: OSWElement
}

extension OSWPolicy {
    static let `default` = OSWPolicy(oswElement: .BareNode)
}
