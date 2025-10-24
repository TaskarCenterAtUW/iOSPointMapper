//
//  ProgressBar.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/26/24.
//

import SwiftUI

struct ProgressBar: View {
    var value: Float


    var body: some View {
        ProgressView(value: value)
            .progressViewStyle(LinearProgressViewStyle())
            .padding()
    }
}
