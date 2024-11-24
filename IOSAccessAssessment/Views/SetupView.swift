//
//  SetupView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI

struct SetupView: View {
    @State private var selection = Set<Int>()
    @StateObject private var sharedImageData: SharedImageData = SharedImageData()
    @StateObject private var segmentationModel: SegmentationModel = SegmentationModel()
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Setup View")
                    .font(.largeTitle)
                    .padding(.bottom, 5)
                
                Text("Select Classes to Identify")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                List {
                    ForEach(0..<Constants.ClassConstants.classes.count, id: \.self) { index in
                        Button(action: {
                            if self.selection.contains(index) {
                                self.selection.remove(index)
                            } else {
                                self.selection.insert(index)
                            }
                        }) {
                            Text(Constants.ClassConstants.classes[index])
                                .foregroundColor(self.selection.contains(index) ?
                                                 Color(red: 187/255, green: 134/255, blue: 252/255) : .white)
                        }
                    }
                }
            }
            .padding()
            .navigationBarTitle("Setup View", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(trailing: NavigationLink(destination: ContentView(selection: Array(selection))) {
                Text("Next").foregroundStyle(Color.white).font(.headline)
            })
            .onAppear {
                // This refresh is done asynchronously, because frames get added from the ContentView even after the refresh
                // This kind of delay should be fine, since the very first few frames of capture may not be necessary.
                // MARK: Discuss on the possibility of having an explicit refresh
                // instead of always refreshing when we end up in SetupView (could happen accidentally)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                    self.sharedImageData.refreshData()
                })
            }
        }
        .environmentObject(self.sharedImageData)
        .environmentObject(self.segmentationModel)
        .environment(\.colorScheme, .dark)
    }
}

