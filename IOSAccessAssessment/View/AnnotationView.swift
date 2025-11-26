//
//  AnnotationView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/10/25.
//

import SwiftUI
import CoreLocation
import simd

enum AnnotationViewConstants {
    enum Texts {
        static let annotationViewTitle = "Annotation"
        
        static let currentClassPrefixText = "Selected class: "
        static let finishText = "Finish"
        static let nextText = "Next"
        
        static let loadingPageText = "Loading. Please wait..."
        
        static let managerStatusAlertTitleKey = "Error"
        static let managerStatusAlertDismissButtonKey = "OK"
        static let managerStatusAlertMessageSuffixKey = "Press OK to close this screen."
    }
    
    enum Images {
        static let checkIcon = "checkmark"
        static let ellipsisIcon = "ellipsis"
        static let infoIcon = "info.circle"
        static let closeIcon = "xmark"
        static let errorIcon = "exclamationmark.triangle"
    }
}

enum AnnotationViewError: Error, LocalizedError {
    case classIndexOutofBounds
    case invalidCaptureDataRecord
    case managerConfigurationFailed
    
    var errorDescription: String? {
        switch self {
        case .classIndexOutofBounds:
            return "The Current Class is not in the list."
        case .invalidCaptureDataRecord:
            return "The Current Capture is invalid."
        case .managerConfigurationFailed:
            return "Annotation Configuration failed"
        }
    }
}

class AnnotationClassSelectionViewModel: ObservableObject {
    @Published var currentIndex: Int? = nil
    @Published var currentClass: AccessibilityFeatureClass? = nil
    @Published var annotationOptions: [AnnotationOptionClass] = AnnotationOptionClass.allCases
    @Published var selectedAnnotationOption: AnnotationOptionClass = AnnotationOptionClass.default
    
    func setCurrent(index: Int, classes: [AccessibilityFeatureClass]) throws {
        objectWillChange.send()
        
        guard index < classes.count else {
            throw AnnotationViewError.classIndexOutofBounds
        }
        currentIndex = index
        currentClass = classes[index]
    }
}

class AnnotationInstanceSelectionViewModel: ObservableObject {
    @Published var currentIndex: Int? = nil
    @Published var currentInstance: AccessibilityFeature? = nil
    @Published var annotationOptions: [AnnotationOption] = AnnotationOption.allCases
    @Published var selectedAnnotationOption: AnnotationOption = AnnotationOption.default
}


struct AnnotationView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @Environment(\.dismiss) var dismiss
    
    @StateObject var manager: AnnotationImageManager = AnnotationImageManager()
    
    @StateObject var segmentationAnnontationPipeline: SegmentationAnnotationPipeline = SegmentationAnnotationPipeline()
    
    @State private var managerStatusViewModel = ManagerStatusViewModel() // From ARCameraView
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait // To bind one-way with manager's orientation
    
    @StateObject var classSelectionViewModel = AnnotationClassSelectionViewModel()
    @StateObject var instanceSelectionViewModel = AnnotationInstanceSelectionViewModel()
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text(AnnotationViewConstants.Texts.annotationViewTitle)
                    .font(.headline)
                    .padding()
                Spacer()
            }
            .overlay(
                HStack {
                    Spacer()
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: AnnotationViewConstants.Images.closeIcon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .padding()
                }
            )
            
            if let currentClass = classSelectionViewModel.currentClass {
                mainContent(currentClass: currentClass)
            } else {
                loadingPageView()
            }
        }
        .task {
            await handleOnAppear()
        }
        .onChange(of: classSelectionViewModel.currentClass) { oldClass, newClass in
            print("Changing Class Selection index")
            handleOnClassChange()
        }
        .alert(AnnotationViewConstants.Texts.managerStatusAlertTitleKey, isPresented: $managerStatusViewModel.isFailed, actions: {
            Button(AnnotationViewConstants.Texts.managerStatusAlertDismissButtonKey) {
                managerStatusViewModel.update(isFailed: false, errorMessage: "")
                dismiss()
            }
        }, message: {
            Text(managerStatusViewModel.errorMessage)
        })
    }
    
    private func loadingPageView() -> some View {
        VStack {
            Spacer()
            Text(AnnotationViewConstants.Texts.loadingPageText)
            SpinnerView()
            Spacer()
        }
    }
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        manager.interfaceOrientation.isLandscape ?
        AnyLayout(HStackLayout())(content) :
        AnyLayout(VStackLayout())(content)
    }
    
    private func annotationOptionsView() -> some View {
        VStack(spacing: 10) {
            ForEach(classSelectionViewModel.annotationOptions, id: \.self) { option in
                Button(action: {
                }) {
                    Text(option.rawValue)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(classSelectionViewModel.selectedAnnotationOption == option ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    @ViewBuilder
    private func mainContent(currentClass: AccessibilityFeatureClass) -> some View {
        orientationStack {
            HostedAnnotationImageViewController(annotationImageManager: manager)
            
            VStack {
                HStack {
                    Spacer()
                    Text("\(AnnotationViewConstants.Texts.currentClassPrefixText): \(currentClass.name)")
                    Spacer()
                }
                
                HStack {
                    Spacer()
                    /// Class Instance Picker
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 30)
                
                ProgressBar(value: 0)
                
                HStack {
                    Spacer()
                    annotationOptionsView()
                    Spacer()
                }
                .padding()
                
                Button(action: {
                    confirmAnnotation()
                }) {
                    Text(isCurrentIndexLast() ? AnnotationViewConstants.Texts.finishText : AnnotationViewConstants.Texts.nextText)
                        .padding()
                }
            }
        }
    }
    
    private func isCurrentIndexValid() -> Bool {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
              let currentClassIndex = classSelectionViewModel.currentIndex else {
            return false
        }
        let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
        return (currentClassIndex >= 0 && currentClassIndex < segmentedClasses.count)
    }
    
    private func isCurrentIndexLast() -> Bool {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
              let currentClassIndex = classSelectionViewModel.currentIndex else {
            return false
        }
        let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
        return currentClassIndex == segmentedClasses.count - 1
    }
    
    private func handleOnAppear() async {
        do {
            guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
            try segmentationAnnontationPipeline.configure()
            try manager.configure(
                selectedClasses: selectedClasses, segmentationAnnotationPipeline: segmentationAnnontationPipeline,
                captureImageData: currentCaptureDataRecord
            )
            let captureDataHistory = Array(await sharedAppData.captureDataQueue.snapshot())
            await manager.setupAlignedSegmentationLabelImages(
                captureImageData: currentCaptureDataRecord,
                captureDataHistory: captureDataHistory
            )
            try classSelectionViewModel.setCurrent(index: 0, classes: segmentedClasses)
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageSuffixKey)")
        }
    }
    
    private func handleOnClassChange() {
        do {
            guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
                  let captureMeshData = currentCaptureDataRecord as? (any CaptureMeshDataProtocol),
                  let currentClass = classSelectionViewModel.currentClass else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            try manager.update(
                captureImageData: currentCaptureDataRecord, captureMeshData: captureMeshData,
                accessibilityFeatureClass: currentClass
            )
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageSuffixKey)")
        }
    }
    
    private func confirmAnnotation() {
        guard (!isCurrentIndexLast()) else {
            self.dismiss()
            return
        }
        do {
            guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
                  let currentClassIndex = classSelectionViewModel.currentIndex else {
                throw AnnotationViewError.invalidCaptureDataRecord
            }
            let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
            try classSelectionViewModel.setCurrent(index: currentClassIndex + 1, classes: segmentedClasses)
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageSuffixKey)")
        }
    }
}
