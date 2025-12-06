//
//  InvalidContentSheet.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI

enum InvalidContentViewConstants {
    enum Images {
        static let closeIcon: String = "xmark"
    }
}

struct InvalidContentView: View {
    let title: String
    let message: String
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text(title)
                    .font(.headline)
                    .padding()
                Spacer()
            }
            .overlay(
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: InvalidContentViewConstants.Images.closeIcon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .padding()
                }
            )
            
            Spacer()
            Text(message)
                .multilineTextAlignment(.center)
                .padding()
            Spacer()
        }
    }
}
