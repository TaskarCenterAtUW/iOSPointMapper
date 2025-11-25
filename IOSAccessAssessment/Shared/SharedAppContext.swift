//
//  SharedAppContext.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/24/25.
//

final class SharedAppContext: ObservableObject {
    var metalContext: MetalContext?
    
    func configure() throws {
        metalContext = try MetalContext()
    }
}
