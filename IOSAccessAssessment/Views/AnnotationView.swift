//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
struct AnnotationView: View {
    
    enum AnnotationOption: String, CaseIterable {
        case agree = "I agree with this class annotation"
        case missingInstances = "Annotation is missing some instances of the class"
        case misidentified = "The class annotation is misidentified"
    }
    
    @EnvironmentObject var sharedImageData: SharedImageData
    
    var objectLocation: ObjectLocation
    var classes: [String]
    var selection: [Int]
    
    @State private var index = 0
    @State private var selectedOption: AnnotationOption? = nil
    @State private var isShowingClassSelectionModal: Bool = false
    @State private var selectedClassIndex: Int? = nil
    @State private var tempSelectedClassIndex: Int = 0
    @Environment(\.dismiss) var dismiss
    
    let options = AnnotationOption.allCases
    
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
                        HostedAnnotationCameraViewController(index: index,
                                                             frameRect: VerticalFrame.getColumnFrame(
                                                                width: UIScreen.main.bounds.width,
                                                                height: UIScreen.main.bounds.height,
                                                                row: 0)
                        )
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("Selected class: \(classes[sharedImageData.segmentedIndices[index]])")
                        Spacer()
                    }
                    
                    ProgressBar(value: calculateProgress())
                    
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ForEach(options, id: \.self) { option in
                                Button(action: {
                                    selectedOption = (selectedOption == option) ? nil : option
                                    
                                    if option == .misidentified {
                                        selectedClassIndex = index
                                        tempSelectedClassIndex = sharedImageData.segmentedIndices[index]
                                        isShowingClassSelectionModal = true
                                    }
                                }) {
                                    Text(option.rawValue)
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(selectedOption == option ? Color.blue : Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    
                    Button(action: {
                        objectLocation.calcLocation(sharedImageData: sharedImageData, index: index)
                        self.nextSegment()
                        selectedOption = nil
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
                    let filteredClasses = selection.map { classes[$0] }
                    
                    // mapping between filtered and non-filtered
                    let selectedFilteredIndex = selection.firstIndex(of: sharedImageData.segmentedIndices[selectedClassIndex]) ?? 0
                    
                    let selectedClassBinding: Binding<Array<Int>.Index> = Binding(
                        get: { selectedFilteredIndex },
                        set: { newValue in
                            let originalIndex = selection[newValue]
                            // Update the segmentedIndices inside sharedImageData
                            sharedImageData.segmentedIndices[selectedClassIndex] = originalIndex
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
        if (self.sharedImageData.segmentedIndices.isEmpty || (index >= self.sharedImageData.segmentedIndices.count)) {
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
        return Float(self.index) / Float(self.sharedImageData.segmentedIndices.count)
    }
}

struct ClassSelectionView: View {
    var classes: [String]
    @Binding var selectedClass: Int
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Select correct annotation")
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
