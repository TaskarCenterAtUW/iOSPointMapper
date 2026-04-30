//
//  Extensions.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/28/26.
//

import Foundation

public extension Double {
    public func roundedTo7Digits() -> Double {
        (self * 1_000_0000).rounded() / 1_000_0000
    }
}
