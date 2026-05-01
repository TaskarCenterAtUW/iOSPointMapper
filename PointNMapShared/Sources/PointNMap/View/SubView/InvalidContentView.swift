//
//  InvalidContentSheet.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 12/1/25.
//

import SwiftUI

public enum InvalidContentViewConstants {
    public enum Images {
        public static let closeIcon: String = "xmark"
    }
}

public struct InvalidContentView: View {
    public let title: String
    public let message: String
    
    @Environment(\.dismiss) public var dismiss
    
    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }
    
    public var body: some View {
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
