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
    let options = AnnotationOption.allCases
    
    let annotationCIContext = CIContext()
    
    @EnvironmentObject var sharedImageData: SharedImageData
    
    @State private var index = 0
    
    var objectLocation: ObjectLocation
    var classes: [String] // Might want to replace this with the global Constants object reference
    var selection: [Int]
    
    @State private var selectedOption: AnnotationOption? = nil
    @State private var isShowingClassSelectionModal: Bool = false
    @State private var selectedClassIndex: Int? = nil
    @State private var tempSelectedClassIndex: Int = 0
    
    @State private var cameraUIImage: UIImage? = nil
    @State private var segmentationUIImage: UIImage? = nil
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        if (!self.isValid()) {
            Rectangle()
                .frame(width: 0, height: 0)
                .onAppear {
                    refreshView()
                }
            
        } else {
            VStack {
                HStack {
                    Spacer()
                    HostedAnnotationCameraViewController(cameraImage: cameraUIImage!,
                                                         segmentationImage: segmentationUIImage!,
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
                    selectedOption = nil
                    uploadChanges()
                    nextSegment()
                }) {
                    Text(index == selection.count - 1 ? "Finish" : "Next")
                }
                .padding()
            }
            .navigationBarTitle("Annotation View", displayMode: .inline)
            .onAppear {
                refreshView()
            }
            .onDisappear {
                closeChangeset()
            }
            .onChange(of: index, initial: true) { oldIndex, newIndex in
                // Trigger any additional actions when the index changes
                refreshView()
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
        if (self.cameraUIImage == nil || self.segmentationUIImage == nil) {
            return false
        }
        return true
    }
    
    func refreshView() {
        let start = DispatchTime.now()
        // Any additional refresh logic can be placed here
        // Example: fetching new data, triggering animations, sending current data etc.
        let depthCGImage = annotationCIContext.createCGImage(
            sharedImageData.depthImage!, from: sharedImageData.depthImage!.extent)!
        let depthUIImage = UIImage(cgImage: depthCGImage, scale: 1.0, orientation: .downMirrored)
        
        let segmentationLabelImage = annotationCIContext.createCGImage(
            sharedImageData.segmentationLabelImage!, from: sharedImageData.segmentationLabelImage!.extent)!
        let segmentationLabelUIImage = UIImage(cgImage: segmentationLabelImage, scale: 1.0, orientation: .right)
        let classIndex = sharedImageData.segmentedIndices[index]
//        self.segmentationUIImage = OpenCVWrapper.perform1DWatershed(segmentationLabelUIImage, depthUIImage,
//                                        Int32(Constants.ClassConstants.labels[classIndex]))
        let result = OpenCVWrapper.perform1DWatershedWithContoursColors(maskImage: segmentationLabelUIImage, depthImage: depthUIImage, labelValue: Int32(Constants.ClassConstants.labels[classIndex]))
        self.segmentationUIImage = result.image
        let resultContours = result.contours
        
        let end = DispatchTime.now()
        
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000
//        print("Time taken to post-process AnnotationView segments: \(timeInterval) milliseconds")
        
        let cameraCGImage = annotationCIContext.createCGImage(
            sharedImageData.cameraImage!, from: sharedImageData.cameraImage!.extent)!
        self.cameraUIImage = UIImage(cgImage: cameraCGImage, scale: 1.0, orientation: .right)
    }
    
    func nextSegment() {
        // Ensure that the index does not exceed the length of the sharedImageData classImages count
        // Do not simply rely on the isValid check in the body. 
        if (self.index + 1 < sharedImageData.classImages.count) {
            self.index += 1
        } else {
            self.dismiss()
        }
    }

    func calculateProgress() -> Float {
        return Float(self.index) / Float(self.sharedImageData.segmentedIndices.count)
    }
    
    private func uploadChanges() {
        guard let nodeLatitude = objectLocation.latitude,
              let nodeLongitude = objectLocation.longitude
        else { return }
        
        let tags: [String: String] = ["demo:class":classes[sharedImageData.segmentedIndices[index]]]
        let nodeData = NodeData(latitude: nodeLatitude, longitude: nodeLongitude, tags: tags)
        
        ChangesetService.shared.uploadChanges(nodeData: nodeData) { result in
            switch result {
            case .success:
                print("Changes uploaded successfully.")
            case .failure(let error):
                print("Failed to upload changes: \(error.localizedDescription)")
            }
        }
    }
    
    private func closeChangeset() {
        ChangesetService.shared.closeChangeset { result in
            switch result {
            case .success:
                print("Changeset closed successfully.")
            case .failure(let error):
                print("Failed to close changeset: \(error.localizedDescription)")
            }
        }
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
