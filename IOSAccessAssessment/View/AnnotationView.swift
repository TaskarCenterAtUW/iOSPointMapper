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
        static let ellipsisIcon = "ellipsis"
    }
}

struct AnnotationView: View {
    var selection: [Int]
    var objectLocation: ObjectLocation
    
    @EnvironmentObject var sharedImageData: SharedImageData
    @Environment(\.dismiss) var dismiss
    
    @State var index = 0
    
    @State var options: [AnnotationOption] = AnnotationOptionClass.allCases.map { .classOption($0) }
    @State private var selectedOption: AnnotationOption? = nil
    @State private var isShowingClassSelectionModal: Bool = false
    @State var isShowingAnnotationInstanceDetailView: Bool = false
    @State var selectedClassIndex: Int? = nil
    @State private var tempSelectedClassIndex: Int = 0
    
    @State private var isDepthModalPresented: Bool = false
    @State var currentDepthValues: String = ""
    
    @StateObject var annotationImageManager = AnnotationImageManager()
    
    @State var depthMapProcessor: DepthMapProcessor? = nil
    
    @State private var confirmAnnotationFailed: Bool = false
    
    // For deciding the layout
    @StateObject private var orientationObserver = OrientationObserver()
    
    // MARK: Width Field Demo: Temporary variable for number formatter
    @State private var numberFormatter: NumberFormatter = {
        var nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf
    }()
    
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
//                ScrollView(.vertical) {
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
                            openAnnotationInstanceDetailView()
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
//                }
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
                    calculateWidth(selectedObjectId: newValue)
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
            .alert("Current Depth Value", isPresented: $isDepthModalPresented) {
                Button("OK") {
                    isDepthModalPresented = false
                    nextSegmentTrue()
                }
            } message: {
                Text(currentDepthValues)
            }
            // TODO: Need to check if the following vetting is necessary
//            .sheet(isPresented: $isShowingClassSelectionModal) {
//                classSelectionView()
//            }
            .sheet(isPresented: $isShowingAnnotationInstanceDetailView) {
                annotationInstanceDetailView()
            }
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
        if index >= sharedImageData.segmentedIndices.count {
            print("Index out of bounds in refreshView")
            return
        }
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
        var currentDepthValues: [Float] = []
        
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
            if segmentationLabelImage.pixelBuffer == nil {
                print("Segmentation label image is nil. Cannot calculate depth by radius.")
                depthValue = depthMapProcessor.getDepth(
                    segmentationLabelImage: segmentationLabelImage, object: detectedObject,
                    depthImage: depthImage,
                    classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
            } else {
                depthValue = depthMapProcessor.getDepthInRadius(
                    segmentationLabelImage: segmentationLabelImage, object: detectedObject,
                    depthRadius: 5, depthImage: depthImage,
                    classLabel: Constants.ClassConstants.labels[sharedImageData.segmentedIndices[index]])
            }
//            var annotatedDetectedObject = annotatedDetectedObject
            annotatedDetectedObject.depthValue = depthValue
            
//            currentDepthValues.append(depthValue)
            currentDepthValues.append(Float(annotatedDetectedObject.object?.centroid.x ?? 0))
            currentDepthValues.append(Float(annotatedDetectedObject.object?.centroid.y ?? 0))
        }
        
        // Update the current depth values for display
        var currentDepthValueString = currentDepthValues.map { String(format: "%.2f", $0) }.joined(separator: ", ")
        self.currentDepthValues = currentDepthValueString
        
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
        self.isDepthModalPresented = true
    }
    
    func nextSegmentTrue() {
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
    
    // MARK: Width Field Demo: Temporary function to calculate width of a way-type object
    func calculateWidth(selectedObjectId: UUID) {
        let selectionClass = Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]]
        if !(selectionClass.isWay) {
            return
        }
        
        var width: Float = 0.0
        // If the current class is way-type, we should calculate the width of the selected object
        if let selectedObject = annotationImageManager.annotatedDetectedObjects?.first(where: { $0.id == selectedObjectId }),
           let selectedObjectObject = selectedObject.object
           {
            if (selectedObjectObject.calculatedWidth != nil) {
                width = selectedObjectObject.finalWidth ?? selectedObjectObject.calculatedWidth ?? 0.0
            } else {
                // Calculate the width of the selected object
                let wayBoundsWithDepth = getWayBoundsWithDepth(wayBounds: selectedObject.object?.wayBounds ?? [])
                let imageSize = annotationImageManager.segmentationUIImage?.size ?? CGSize.zero
                if let wayBoundsWithDepth = wayBoundsWithDepth {
                    width = objectLocation.getWayWidth(
                        wayBoundsWithDepth: wayBoundsWithDepth,
                        imageSize: annotationImageManager.segmentationUIImage?.size ?? CGSize.zero,
                        cameraTransform: self.sharedImageData.cameraTransform,
                        cameraIntrinsics: self.sharedImageData.cameraIntrinsics,
                        deviceOrientation: self.sharedImageData.deviceOrientation ?? .landscapeLeft,
                        originalImageSize: self.sharedImageData.originalImageSize ?? imageSize
                    )
                    selectedObjectObject.calculatedWidth = width
                }
            }
        }
        // Update the width in the annotationImageManager
        annotationImageManager.selectedObjectWidth = width
    }
    
    func calculateBreakage(selectedObjectId: UUID) {
        let selectionClass = Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]]
        if !(selectionClass.isWay) {
            return
        }
        
        let segmentationClass = Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]]
        var breakageStatus: Bool = false
        if let selectedObject = annotationImageManager.annotatedDetectedObjects?.first(where: { $0.id == selectedObjectId }),
           let selectedObjectObject = selectedObject.object,
           let width = selectedObjectObject.finalWidth ?? selectedObjectObject.calculatedWidth {
            breakageStatus = self.getBreakageStatus(
                width: width,
                wayWidth: self.sharedImageData.wayWidthHistory[segmentationClass.labelValue]?.last)
            selectedObjectObject.calculatedBreakage = breakageStatus
        }
        // Update the breakage status in the annotationImageManager
        annotationImageManager.selectedObjectBreakage = breakageStatus
    }
    
    func getBreakageStatus(width: Float, wayWidth: WayWidth?) -> Bool {
        print("Way Width: \(wayWidth?.widths ?? [])")
        guard let wayWidth = wayWidth else {
            return false
        }
        let widths = wayWidth.widths
        // Check if width is lower than mean - 2 standard deviations of the mean (if the length of widths array is greater than 3)
        guard widths.count >= 3 else {
            return false
        }
        let sum = widths.reduce(0, +)
        let avg = sum / Float(widths.count)
        let v = widths.reduce(0, { $0 + ($1-avg)*($1-avg) })
        let stdDev = sqrt(v / (Float(widths.count)-1))
        let lowerBound = avg - 2 * stdDev
        print("Width: \(width), Avg: \(avg), StdDev: \(stdDev), Lower Bound: \(lowerBound)")
        return width < lowerBound
    }
}
