//
//  SetupView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI

struct SetupView: View {
//    let classes = ["Background", "Aeroplane", "Bicycle", "Bird", "Boat", "Bottle", "Bus", "Car", "Cat", "Chair", "Cow", "Diningtable", "Dog", "Horse", "Motorbike", "Person", "Pottedplant", "Sheep", "Sofa", "Train", "TV"]
    let classes = ["Sidewalk", "Traffic Light", "Pole", "Wall", "Fence", "Person", "Miscellaneous"]
    @State private var selection = Set<Int>()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Setup View")
                    .font(.largeTitle)
                    .padding(.bottom, 5)
                
                Text("Select Classes to Identify")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                List {
                    ForEach(0..<classes.count, id: \.self) { index in
                        Button(action: {
                            if self.selection.contains(index) {
                                self.selection.remove(index)
                            } else {
                                self.selection.insert(index)
                            }
                        }) {
                            Text(classes[index])
                                .foregroundColor(self.selection.contains(index) ? .blue : .white)
                        }
                    }
                }
                .environment(\.colorScheme, .dark)
            }
            .padding()
            .navigationBarTitle("Setup View", displayMode: .inline)
            .navigationBarItems(trailing: NavigationLink(destination: ContentView(selection: Array(selection), classes: classes)) {
                Text("Next").foregroundStyle(Color.white).font(.headline)
            })
        }.environment(\.colorScheme, .dark)
    }
}

