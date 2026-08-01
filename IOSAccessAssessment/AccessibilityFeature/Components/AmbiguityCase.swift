//
//  AmbiguityCase.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/1/26.
//

import Foundation

enum AmbiguityCase: String, CaseIterable, Sendable, Codable, Equatable, Hashable {
    case parallel_sidewalks = "Parallel Sidewalks"
    case wide_plazas = "Wide Plazas"
    case closely_spaced_features = "Closely Spaced"
    case divided_or_offset_crossings = "Divided or Offset Crossings"
    case multiple_intersection_corners = "Multiple Intersection Corners"
    case partial_masks = "Partial Masks"
    case no_ambiguity = "No Ambiguity"
}

struct AmbiguityCasePolicy: Sendable, Codable, Equatable, Hashable {
    let ambiguityCases: [AmbiguityCase]
}

extension AmbiguityCasePolicy {
    static let `default` = AmbiguityCasePolicy(ambiguityCases: [.no_ambiguity])
}
