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
    
    let options = [
        "I agree with this class annotation",
        "Annotation is missing some instances of the class",
        "The class annotation is misidentified"
    ]
    
    @State private var selectedOptionIndex: Int? = nil
    @State private var isShowingClassSelectionModal: Bool = false
    @State private var selectedClassIndex: Int? = nil
    @State private var tempSelectedClassIndex: Int = 0
    
    var objectLocation: ObjectLocation
    @State var selection: [Int]
    var classes: [String]
    var selectedClassesIndices: [Int]
    
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
                    // TODO: Alternatively, consider never navigating from ContentView to begin with when segments are empty
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
                                    
                                    if optionIndex == 2 {
                                        selectedClassIndex = index
                                        tempSelectedClassIndex = selection[index]
                                        isShowingClassSelectionModal = true
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
                if (!self.isValid()) {
                    self.dismiss()
                }
            }
            .onChange(of: index) { _ in
                // Trigger any additional actions when the index changes
                self.refreshView()
            }
            .sheet(isPresented: $isShowingClassSelectionModal) {
                if let selectedClassIndex = selectedClassIndex {
                    let filteredClasses = selectedClassesIndices.map { classes[$0] }
                    
                    // mapping between filtered and non-filtered
                    let selectedFilteredIndex = selectedClassesIndices.firstIndex(of: selection[selectedClassIndex]) ?? 0
                    
                    let selectedClassBinding = Binding(
                        get: { selectedFilteredIndex },
                        set: { newValue in
                            let originalIndex = selectedClassesIndices[newValue]
                            selection[selectedClassIndex] = originalIndex
                        }
                    )
                    
                    ClassSelectionView(
                        classes: filteredClasses,
                        selectedClass: selectedClassBinding
                    )
                }
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

struct ClassSelectionView: View {
    var classes: [String]
    @Binding var selectedClass: Int
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Select a new POI Class")
                .font(.headline)
                .padding()

            List {
                ForEach(0..<classes.count, id: \.self) { index in
                    Button(action: {
                        selectedClass = index
                    }) {
                        HStack {
                            Text(classes[index])
                            Spacer()
                            if selectedClass == index {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .padding()
            }
        }
    }
}
