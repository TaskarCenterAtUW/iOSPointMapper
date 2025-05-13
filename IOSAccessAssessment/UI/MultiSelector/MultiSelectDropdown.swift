//
//  MultiSelectDropdown.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 5/12/25.
//

import SwiftUI

struct MultiSelectDropdown: View {
    let options: [String]
    @Binding var selected: Set<String>
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
//                withAnimation {
                isExpanded.toggle()
//                }
            }) {
                HStack {
                    Text(selected.isEmpty ? "Select options" : selected.joined(separator: ", "))
                        .foregroundColor(selected.isEmpty ? .gray : .primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            if selected.contains(option) {
                                selected.remove(option)
                            } else {
                                selected.insert(option)
                            }
                        }) {
                            HStack {
                                Text(option)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selected.contains(option) {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal)
                        }
                        .background(Color(.systemGray6))
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
