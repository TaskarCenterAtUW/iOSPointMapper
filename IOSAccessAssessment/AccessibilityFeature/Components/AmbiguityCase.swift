//
//  AmbiguityCase.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/1/26.
//

import Foundation

enum AmbiguityCase: String, CaseIterable, Sendable, Codable, Equatable, Hashable {
    case parallel_sidewalks = "parallel_sidewalks"
    case wide_plazas = "wide_plazas"
    case closely_spaced_features = "closely_spaced_features"
    case divided_or_offset_crossings = "divided_or_offset_crossings"
    case multiple_intersection_corners = "multiple_intersection_corners"
    case partial_masks = "partial_masks"
    case no_ambiguity = "no_ambiguity"
}

struct AmbiguityCasePolicy: Sendable, Codable, Equatable, Hashable {
    let ambiguityCases: [AmbiguityCase]
}

extension AmbiguityCasePolicy {
    static let `default` = AmbiguityCasePolicy(ambiguityCases: AmbiguityCase.allCases)
}
