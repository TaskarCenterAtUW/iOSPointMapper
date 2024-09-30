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
    
    let options = ["I agree with this class annotation", "Annotation is missing some instances of the class", "The class annotation is misidentified"]
    @State private var selectedOptionIndex: Int? = nil
    
    var objectLocation: ObjectLocation
    var selection: [Int]
    var classes: [String]
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        if (!self.isValid()) {
            Rectangle()
                .frame(width: 0, height: 0)
                .onAppear() {
                    // TODO: Currently, this delay seems to work the best for automatic back navigation
                    //  Need to figure out a way to programmatically navigate without issues when done synchronously.
                    //  Currently, when done synchronously, the onAppear of the previous view does not run
                    //  as the previous view may be considered to have not disappeared.
                    //  May have to do with the way SwiftUI runs the view lifecycle update. 
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.dismiss()
                    }
                }
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
                            ForEach(0..<options.count, id: \.self) { optionIndex in
                                Button(action: {
                                    // Toggle selection
                                    if selectedOptionIndex == optionIndex {
                                        selectedOptionIndex = nil
                                    } else {
                                        selectedOptionIndex = optionIndex
                                    }
                                }) {
                                    Text(options[optionIndex])
                                        .padding()
                                        .foregroundColor(selectedOptionIndex == optionIndex ? .red : .blue) // Change color based on selection
                                }
                            }
                        }
                        Spacer()
                    }
                    
                    Button(action: {
                        objectLocation.calcLocation(sharedImageData: sharedImageData, index: index)
                        self.nextSegment()
                        selectedOptionIndex = nil
                    }) {
                        Text("Next")
                    }
                    .padding()
                }
            }
            .navigationBarTitle("Annotation View", displayMode: .inline)
            .onAppear {
                print("AnnotationView isValid 2 \(self.selection.isEmpty), \(index) vs \(self.selection.count)")
                if (!self.isValid()) {
                    self.dismiss()
                }
            }
            .onChange(of: index) { _ in
                // Trigger any additional actions when the index changes
                self.refreshView()
            }
        }
    }
    
    func isValid() -> Bool {
        if (self.selection.isEmpty || (index >= self.selection.count)) {
            return false
        }
        return true
    }
    
    func nextSegment() {
        self.index += 1
    }

    func refreshView() {
        // Any additional refresh logic can be placed here
        // Example: fetching new data, triggering animations, sending current data etc.
    }

    func calculateProgress() -> Float {
        return Float(self.index) / Float(self.selection.count)
    }
}
