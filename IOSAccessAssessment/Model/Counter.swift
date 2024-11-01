//
//  Counter.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 11/1/24.
//

import Foundation

class Counter {
    static let shared = Counter()
    
    private(set) var count = 0
    
    private init() {}
    
    func increment() {
        self.count += 1
    }
}
