//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
struct AnnotationView: View {
    @ObservedObject var sharedImageData: SharedImageData
    @State private var index = 0
    @State private var selectedIndex: Int? = nil
    @State private var isShowingCameraView = false
    @State private var isUpdatingSegmentation = false
    var objectLocation: ObjectLocation
    var selection: [Int]
    var classes: [String]
    let options = ["I agree with this class annotation", "Annotation is missing some instances of the class", "The class annotation is misidentified"]
    
    var body: some View {
        // TODO: Instead of adding the ContentView again to the NavigationStack,
        //  it would be better to go to the previous screen in the NavigationStack once we are done with the AnnotationView
        //  This way, if the ContentView is the previous view (in the current flow, it always is),
        //  then we avoid having to recreate it again.
        if isShowingCameraView || self.index >= sharedImageData.classImages.count {
            ContentView(selection: Array(selection))
        } else {
            ZStack {
                VStack {
                    HStack {
                        Spacer()
                        HostedAnnotationCameraViewController(sharedImageData: sharedImageData, index: index)
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("Selected class: \(classes[selection[index]])")
                        Spacer()
                    }
                    
                    ProgressBar(value: calculateProgress())
                    
                    HStack {
                        Spacer()
                        VStack {
                            ForEach(0..<options.count) { index in
                                Button(action: {
                                    // Toggle selection
                                    if selectedIndex == index {
                                        selectedIndex = nil
                                    } else {
                                        selectedIndex = index
                                    }
                                }) {
                                    Text(options[index])
                                        .padding()
                                        .foregroundColor(selectedIndex == index ? .red : .blue) // Change color based on selection
                                }
                            }
                        }
                        Spacer()
                    }
                    
                    Button(action: {
                        objectLocation.calcLocation(sharedImageData: sharedImageData, index: index)
                        self.nextSegment()
                        selectedIndex = nil
                    }) {
                        Text("Next")
                    }
                    .padding()
                    .disabled(isUpdatingSegmentation)
                }
            }
            .navigationBarTitle("Annotation View", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: Button(action: {
                // This action depends on how you manage navigation
                // For demonstration, this simply dismisses the view, but you need a different mechanism to navigate to CameraView
                self.isShowingCameraView = true;
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.blue)
                Text("Camera View")
            })
            .onChange(of: index) { _ in
                // Trigger any additional actions when the index changes
                self.refreshView()
            }
        }
    }
    
    func nextSegment() {
        self.index += 1
        if self.index >= (sharedImageData.classImages.count) {
            // Handle completion, save responses, or navigate to the next screen
            ContentView(selection: Array(selection))
        }
    }

    func refreshView() {
        // Any additional refresh logic can be placed here
        // Example: fetching new data, triggering animations, etc.
    }

    func calculateProgress() -> Float {
        return Float(self.index) / Float(selection.count)
    }
}
