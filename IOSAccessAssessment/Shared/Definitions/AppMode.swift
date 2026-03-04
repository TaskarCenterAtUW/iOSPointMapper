//
//  AppMode.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import Foundation

enum AppMode: String, Identifiable, CaseIterable, Hashable, Codable, Sendable {
    case standard
    case test
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .standard:
            return "Standard"
        case .test:
            return "Test"
        }
    }
}
