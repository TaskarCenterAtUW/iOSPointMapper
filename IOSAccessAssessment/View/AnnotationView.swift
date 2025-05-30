//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
import CoreLocation
import simd

enum AnnotationViewConstants {
    enum Texts {
        static let annotationViewTitle = "Annotation View"
        
        static let selectedClassPrefixText = "Selected class: "
        static let finishText = "Finish"
        static let nextText = "Next"
        
        static let selectObjectText = "Select an object"
        static let selectAllLabelText = "Select All"
        
        static let confirmAnnotationFailedTitle = "Cannot confirm annotation"
        static let depthOrSegmentationUnavailableText = "Depth or segmentation related information is not available." +
        "\nDo you want to upload all the objects as a single point with the current location?"
        static let confirmAnnotationFailedConfirmText = "Yes"
        static let confirmAnnotationFailedCancelText = "No"
        
        static let selectCorrectAnnotationText = "Select correct annotation"
        static let doneText = "Done"
    }
    
    enum Images {
        static let checkIcon = "checkmark"
    }
}

struct AnnotationView: View {
    var selection: [Int]
    var objectLocation: ObjectLocation
    
    @EnvironmentObject var sharedImageData: SharedImageData
    @Environment(\.dismiss) var dismiss
    
    @State private var index = 0
    
    @State var options: [AnnotationOption] = AnnotationOptionClass.allCases.map { .classOption($0) }
    @State private var selectedOption: AnnotationOption? = nil
    @State private var isShowingClassSelectionModal: Bool = false
    @State private var selectedClassIndex: Int? = nil
    @State private var tempSelectedClassIndex: Int = 0
    
    @StateObject var annotationImageManager = AnnotationImageManager()
    
    @State var depthMapProcessor: DepthMapProcessor? = nil
    
    @State private var confirmAnnotationFailed: Bool = false
    
    // For deciding the layout
    @StateObject private var orientationObserver = OrientationObserver()
    
    var body: some View {
        if (!self.isValid()) {
            // FIXME: When no segments are available, this view does not dismiss anymore.
            Rectangle().frame(width: 0, height: 0).onAppear {
                refreshView()
            }
        } else {
            orientationStack {
                HStack {
                    Spacer()
                    HostedAnnotationCameraViewController(
                        cameraImage: annotationImageManager.cameraUIImage!,
                        segmentationImage: annotationImageManager.segmentationUIImage!,
                        objectsImage: annotationImageManager.objectsUIImage!
                    )
                    Spacer()
                }
                VStack {
                    HStack {
                        Spacer()
                        Text("\(AnnotationViewConstants.Texts.selectedClassPrefixText): \(Constants.ClassConstants.classNames[sharedImageData.segmentedIndices[index]])")
                        Spacer()
                    }
                    
                    HStack {
                        Picker(AnnotationViewConstants.Texts.selectObjectText, selection: $annotationImageManager.selectedObjectId) {
                            ForEach(annotationImageManager.annotatedDetectedObjects ?? [], id: \.id) { object in
                                Text(object.label ?? "")
                                    .tag(object.id)
                            }
                        }
                    }
                    
                    ProgressBar(value: calculateProgress())
                    
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            ForEach(options, id: \.self) { option in
                                Button(action: {
                                    // Update the selected option
                                    updateAnnotation(newOption: option)

//                                    selectedOption = (selectedOption == option) ? nil : option
                                    
//                                    if option == .misidentified {
//                                        selectedClassIndex = index
//                                        tempSelectedClassIndex = sharedImageData.segmentedIndices[index]
//                                        isShowingClassSelectionModal = true
//                                    }
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
                        Text(index == selection.count - 1 ? AnnotationViewConstants.Texts.finishText : AnnotationViewConstants.Texts.nextText)
                    }
                    .padding()
                }
            }
            .padding(.top, 20)
            .navigationBarTitle(AnnotationViewConstants.Texts.annotationViewTitle, displayMode: .inline)
            .onAppear {
                // Initialize the depthMapProcessor with the current depth image
                depthMapProcessor = DepthMapProcessor(depthImage: sharedImageData.depthImage!)
//                initializeAnnotationSegmentationPipeline()
                refreshView()
                refreshOptions()
            }
            .onChange(of: annotationImageManager.selectedObjectId) { oldValue, newValue in
                if let newValue = newValue {
                    annotationImageManager.updateObjectSelection(previousSelectedObjectId: oldValue, selectedObjectId: newValue)
                    refreshOptions()
                }
            }
            .onChange(of: index, initial: false) { oldIndex, newIndex in
                // Trigger any additional actions when the index changes
                refreshView()
                refreshOptions()
            }
            .alert(AnnotationViewConstants.Texts.confirmAnnotationFailedTitle, isPresented: $confirmAnnotationFailed) {
                Button(AnnotationViewConstants.Texts.confirmAnnotationFailedCancelText, role: .cancel) {
                    confirmAnnotationFailed = false
                    nextSegment()
                }
                Button(AnnotationViewConstants.Texts.confirmAnnotationFailedConfirmText) {
                    confirmAnnotationFailed = false
                    confirmAnnotationWithoutDepth()
                }
            } message: {
                Text(AnnotationViewConstants.Texts.depthOrSegmentationUnavailableText)
            }
            // TODO: Need to check if the following vetting is necessary
//            .sheet(isPresented: $isShowingClassSelectionModal) {
//                classSelectionView()
//            }
        }
    }
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let isLandscape = CameraOrientation.isLandscapeOrientation(
            currentDeviceOrientation: orientationObserver.deviceOrientation)
        if isLandscape {
            HStack(content: content)
        } else {
            VStack(content: content)
        }
    }
    
    func isValid() -> Bool {
        if (self.sharedImageData.segmentedIndices.isEmpty || (index >= self.sharedImageData.segmentedIndices.count)) {
            print("Invalid index or segmentedIndices in AnnotationView")
            return false
        }
        if self.annotationImageManager.isImageInvalid() {
            return false
        }
        return true
    }
    
    func refreshView() {
        let segmentationClass = Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]]
        self.annotationImageManager.update(
            cameraImage: sharedImageData.cameraImage!,
            segmentationLabelImage: sharedImageData.segmentationLabelImage!,
            imageHistory: sharedImageData.getImageDataHistory(),
            segmentationClass: segmentationClass)
    }
    
    func refreshOptions() {
        
        if let selectedObjectId = annotationImageManager.selectedObjectId,
           let annotatedDetectedObjects = annotationImageManager.annotatedDetectedObjects {
            let selectedObject = annotatedDetectedObjects.first(where: { $0.id == selectedObjectId })
            if let selectedObject = selectedObject {
                options = selectedObject.isAll ?
                AnnotationOptionClass.allCases.map { .classOption($0) } :
                AnnotationOptionObject.allCases.map { .individualOption($0) }
                selectedOption = selectedObject.selectedOption
            } else {
                options = AnnotationOptionClass.allCases.map { .classOption($0) }
            }
        }
    }
    
    func updateAnnotation(newOption: AnnotationOption) {
        if let selectedObjectId = annotationImageManager.selectedObjectId,
           let annotatedDetectedObjects = annotationImageManager.annotatedDetectedObjects {
            let selectedObject = annotatedDetectedObjects.first(where: { $0.id == selectedObjectId })
            if let selectedObject = selectedObject {
                // Update the selected option for the object
                selectedObject.selectedOption = newOption
                selectedOption = newOption
            } else {
                print("Selected object not found in annotatedDetectedObjects.")
            }
        }
    }
    
    func confirmAnnotation() {
        var depthValue: Float = 0.0
        guard let depthMapProcessor = depthMapProcessor,
              let depthImage = sharedImageData.depthImage,
              let segmentationLabelImage = self.annotationImageManager.annotatedSegmentationLabelImage,
              let annotatedDetectedObjects = self.annotationImageManager.annotatedDetectedObjects
        else {
            confirmAnnotationFailed = true
            return
        }
            
        // TODO: Instead of only using the centroid, use a trimmed mean of the depth values of all the pixels in the object.
        for annotatedDetectedObject in annotatedDetectedObjects {
            guard let detectedObject = annotatedDetectedObject.object else { continue }
            depthValue = depthMapProcessor.getDepth(
                segmentationLabelImage: segmentationLabelImage, object: detectedObject,
                depthImage: depthImage,
                classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
//            var annotatedDetectedObject = annotatedDetectedObject
            annotatedDetectedObject.depthValue = depthValue
        }
        
//        let location = objectLocation.getCalcLocation(depthValue: depthValue)
        let segmentationClass = Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]]
        uploadAnnotatedChanges(annotatedDetectedObjects: annotatedDetectedObjects, segmentationClass: segmentationClass)
        nextSegment()
    }
    
    func confirmAnnotationWithoutDepth() {
        let location = objectLocation.getCalcLocation(depthValue: 0.0)
        let segmentationClass = Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]]
        // Since the depth calculation failed, we are not going to save this node in sharedImageData for future use.
        uploadNodeWithoutDepth(location: location, segmentationClass: segmentationClass)
        nextSegment()
    }
    
    func nextSegment() {
        // Ensure that the index does not exceed the length of the sharedImageData segmentedIndices count
        // Do not simply rely on the isValid check in the body.
        selectedOption = nil
        if (self.index + 1 < sharedImageData.segmentedIndices.count) {
            self.index += 1
        } else {
            self.dismiss()
        }
    }

    func calculateProgress() -> Float {
        return Float(self.index) / Float(self.sharedImageData.segmentedIndices.count)
    }
}

// Extension for loading the ClassSelectionView as sheet
extension AnnotationView {
    @ViewBuilder
    func classSelectionView() -> some View {
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

struct ClassSelectionView: View {
    var classes: [String]
    @Binding var selectedClass: Int
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text(AnnotationViewConstants.Texts.selectCorrectAnnotationText)
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
                                Image(systemName: AnnotationViewConstants.Images.checkIcon)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text(AnnotationViewConstants.Texts.doneText)
                    .padding()
            }
        }
    }
}
