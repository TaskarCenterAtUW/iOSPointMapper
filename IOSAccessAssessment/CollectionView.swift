//
//  CollectionView.swift
//  IOSAccessAssessment
//
//  Created by Sai on 1/25/24.
//

import SwiftUI

struct CollectionView: View {
    var classes: [String]
    var selection: [Int]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(0..<selection.count, id: \.self) { index in
                    CollectionViewCell(label: self.classes[self.selection[index]])
                        .background(
                            Color(
                                red: Double((self.selection[index] * self.selection[index] * 7) % 255) / 255.0,
                                green: Double(12 * self.selection[index]) / 255.0,
                                blue: Double((((self.selection[index] * self.selection[index]) % 21) * 39) % 255) / 255.0
                            )
                        )
                }
            }
        }
    }
}

struct CollectionViewCell: View {
    var label: String
    
    var body: some View {
        Text(label)
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .padding(.horizontal, 10)
    }
}



//#Preview {
//    CollectionView()
//}
