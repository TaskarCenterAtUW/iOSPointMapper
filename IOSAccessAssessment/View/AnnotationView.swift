//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
import CoreLocation

enum AnnotationOption: String, CaseIterable {
    case agree = "I agree with this class annotation"
    case missingInstances = "Annotation is missing some instances of the class"
    case misidentified = "The class annotation is misidentified"
}

struct AnnotationView: View {
    var selection: [Int]
    var objectLocation: ObjectLocation
    
    @EnvironmentObject var sharedImageData: SharedImageData
    @Environment(\.dismiss) var dismiss
    
    @State private var index = 0
    
    @State private var selectedOption: AnnotationOption? = nil
    @State private var isShowingClassSelectionModal: Bool = false
    @State private var selectedClassIndex: Int? = nil
    @State private var tempSelectedClassIndex: Int = 0
    @State private var depthMapProcessor: DepthMapProcessor? = nil
    
    @State private var cameraUIImage: UIImage? = nil
    @State private var segmentationUIImage: UIImage? = nil
    
    let annotationCIContext = CIContext()
    let grayscaleToColorMasker = GrayscaleToColorCIFilter()
    let options = AnnotationOption.allCases
    
    var body: some View {
        if (!self.isValid()) {
            Rectangle().frame(width: 0, height: 0).onAppear {refreshView()}
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
                    Text("Selected class: \(Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]])")
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
                    confirmAnnotation()
                }) {
                    Text(index == selection.count - 1 ? "Finish" : "Next")
                }
                .padding()
            }
            .navigationBarTitle("Annotation View", displayMode: .inline)
            .onAppear {
                // Initialize the depthMapProcessor with the current depth image
                depthMapProcessor = DepthMapProcessor(depthImage: sharedImageData.depthImage!)
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
                    let filteredClasses = selection.map { Constants.ClassConstants.classNames[$0] }
                    
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
        let cameraCGImage = annotationCIContext.createCGImage(
            sharedImageData.cameraImage!, from: sharedImageData.cameraImage!.extent)!
        self.cameraUIImage = UIImage(cgImage: cameraCGImage, scale: 1.0, orientation: .up)
//        self.cameraUIImage = UIImage(ciImage: sharedImageData.depthImage!, scale: 1.0, orientation: .up)
        
        guard index < sharedImageData.segmentedIndices.count else {
            print("Index out of bounds for segmentedIndices in AnnotationView")
            return
        }
        self.grayscaleToColorMasker.inputImage = sharedImageData.segmentationLabelImage
        self.grayscaleToColorMasker.grayscaleValues = [Constants.ClassConstants.grayscaleValues[sharedImageData.segmentedIndices[index]]]
        self.grayscaleToColorMasker.colorValues = [Constants.ClassConstants.colors[sharedImageData.segmentedIndices[index]]]
        self.segmentationUIImage = UIImage(ciImage: self.grayscaleToColorMasker.outputImage!, scale: 1.0, orientation: .up)
        
//        let segmentationCGSize = CGSize(width: sharedImageData.segmentationLabelImage!.extent.width,
//                                            height: sharedImageData.segmentationLabelImage!.extent.height)
//        let segmentationObjects = sharedImageData.detectedObjects.filter { objectID, object in
//            object.classLabel == Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]] &&
//            object.isCurrent == true
//        } .map({ $0.value })
//        let segmentationObjectImage = rasterizeContourObjects(objects: segmentationObjects, size: segmentationCGSize)
//        self.segmentationUIImage = UIImage(ciImage: segmentationObjectImage!, scale: 1.0, orientation: .up)
    }
    
    func confirmAnnotation() {
        var depthValue: Float = 0.0
        if let depthMapProcessor = depthMapProcessor,
           let segmentationLabelImage = sharedImageData.segmentationLabelImage,
           let depthImage = sharedImageData.depthImage {
            depthValue = depthMapProcessor.getDepth(segmentationLabelImage: segmentationLabelImage,
                         depthImage: depthImage,
                         classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
            
            // MARK: Experimentation with detected object
//            let detectedObject = sharedImageData.detectedObjects.filter { objectID, object in
//                object.classLabel == Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]]
//            }
//            if let object = detectedObject.first {
//                let depthValueObject = depthMapProcessor.getDepth(segmentationLabelImage: sharedImageData.segmentationLabelImage!,
//                                                                  object: object.value,
//                                                                  depthImage: sharedImageData.depthImage!,
//                                                                  classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
//                print("Depth Value for Label: \(depthValue) Object: \(depthValueObject)")
//            }
        } else {
            print("depthMapProcessor or segmentationLabelImage is nil. Falling back to default depth value.")
        }
        let location = objectLocation.getCalcLocation(depthValue: depthValue)
        selectedOption = nil
        uploadChanges(location: location)
        nextSegment()
    }
    
    func nextSegment() {
        // Ensure that the index does not exceed the length of the sharedImageData segmentedIndices count
        // Do not simply rely on the isValid check in the body.
        if (self.index + 1 < sharedImageData.segmentedIndices.count) {
            self.index += 1
        } else {
            self.dismiss()
        }
    }

    func calculateProgress() -> Float {
        return Float(self.index) / Float(self.sharedImageData.segmentedIndices.count)
    }
    
    private func uploadChanges(location: (latitude: CLLocationDegrees, longitude: CLLocationDegrees)?) {
        guard let nodeLatitude = location?.latitude,
              let nodeLongitude = location?.longitude
        else { return }
        
        let tags: [String: String] = ["demo:class": Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]]]
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
