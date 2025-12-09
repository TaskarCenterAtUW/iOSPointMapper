//
//  OSWElement.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/8/25.
//

protocol OSWElement: Sendable, Equatable {
    var id: String { get }
    var version: String { get }
    
    var oswElementClass: OSWElementClass { get }
    
}
