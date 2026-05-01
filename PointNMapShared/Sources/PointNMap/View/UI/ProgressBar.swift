//
//  ProgressBar.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/26/24.
//

import SwiftUI

public struct ProgressBar: View {
    public var value: Float
    
    public init(value: Float) {
        self.value = value
    }
    
    public var body: some View {
        ProgressView(value: value)
            .progressViewStyle(LinearProgressViewStyle())
            .padding()
    }
}
