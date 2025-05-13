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

import SwiftUI

struct MultiSelectDropdown2: View {
    let options: [String]
    @Binding var selected: Set<String>

    @State private var isExpanded = false
    @State private var buttonFrame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
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
                .background(GeometryReader { geometry in
                    Color.clear.onAppear {
                        buttonFrame = geometry.frame(in: .global)
                    }
                })
            }

            if isExpanded {
                // Full-screen tap-to-dismiss background
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isExpanded = false
                        }
                    }

                // Floating dropdown list
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
                        .background(Color.white)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(radius: 4))
                .frame(width: buttonFrame.width)
                .position(x: buttonFrame.midX, y: buttonFrame.maxY + 10)
                .zIndex(1)
            }
        }
        .onChange(of: isExpanded) { _ in
            // Refresh geometry when dropdown opens
            if isExpanded {
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}
