//
//  SharedBaseContext.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/24/25.
//
import SwiftUI
import Combine

final class SharedBaseContext: ObservableObject {
    var metalContext: MetalContext?
    var isEnhancedAnalysisEnabled: Bool = false
    
    func configure() throws {
        metalContext = try MetalContext()
    }
}
