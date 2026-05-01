//
//  SpinnerView.swift
//  IOSAccessAssessment
//
//  Created by TCAT on 9/24/24.
//

import SwiftUI

public struct SpinnerView: View {
    public init() {}
    
    public var body: some View {
    ProgressView()
      .progressViewStyle(CircularProgressViewStyle(tint: .blue))
      .scaleEffect(2.0, anchor: .center) // Makes the spinner larger
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          // Simulates a delay in content loading
          // Perform transition to the next view here
        }
      }
  }
}
