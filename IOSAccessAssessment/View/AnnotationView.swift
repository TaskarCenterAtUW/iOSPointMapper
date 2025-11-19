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
        
        static let invalidPageText = "Invalid Content. Please Close."
        
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


struct AnnotationView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @Environment(\.dismiss) var dismiss
    
    @StateObject var manager: AnnotationImageManager = AnnotationImageManager()
    @State private var managerStatusViewModel = ManagerStatusViewModel() // From ARCameraView
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait // To bind one-way with manager's orientation
    @State var currentClassIndex = 0
    @State var currentClass: AccessibilityFeatureClass? = nil
    @State var instanceAnnotationOptions: [AnnotationOption] = AnnotationOption.allCases
    @State var classAnnotationOptions: [AnnotationOptionClass] = AnnotationOptionClass.allCases
    @State var selectedInstanceAnnotationOption: AnnotationOption = AnnotationOption.default
    @State var selectedClassAnnotationOption: AnnotationOptionClass = AnnotationOptionClass.default
    
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
            
            if (isCurrentIndexValid()) {
                mainContent()
                .onAppear() {
                    handleOnAppear()
                }
                .onChange(of: currentClassIndex) { oldValue, newValue in
                    handleOnIndexChange()
                }
            } else {
                invalidPageView()
            }
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
    
    private func invalidPageView() -> some View {
        VStack {
            Label {
                Text(AnnotationViewConstants.Texts.invalidPageText)
            } icon: {
                Image(systemName: AnnotationViewConstants.Images.errorIcon)
            }
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
            ForEach(classAnnotationOptions, id: \.self) { option in
                Button(action: {
                }) {
                    Text(option.rawValue)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedClassAnnotationOption == option ? Color.blue : Color.gray)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    @ViewBuilder
    private func mainContent() -> some View {
        if let currentClass = currentClass {
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
        } else {
            invalidPageView()
        }
    }
    
    private func isCurrentIndexValid() -> Bool {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord else {
            return false
        }
        let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
        guard currentClassIndex >= 0 && currentClassIndex < segmentedClasses.count else {
            return false
        }
        return true
    }
    
    private func isCurrentIndexLast() -> Bool {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord else {
            return false
        }
        let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
        return currentClassIndex == segmentedClasses.count - 1
    }
    
    private func setCurrentClass() throws {
        guard isCurrentIndexValid() else {
            throw AnnotationViewError.classIndexOutofBounds
        }
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord else {
            throw AnnotationViewError.invalidCaptureDataRecord
        }
        let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
        currentClass = segmentedClasses[currentClassIndex]
    }
    
    private func configureManager() throws {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
              let captureMeshData = currentCaptureDataRecord as? (any CaptureMeshDataProtocol),
              let currentClass = currentClass
        else {
            throw AnnotationViewError.invalidCaptureDataRecord
        }
        try manager.configure(selectedClasses: selectedClasses, captureImageData: currentCaptureDataRecord)
        try manager.update(
            captureImageData: currentCaptureDataRecord, captureMeshData: captureMeshData,
            accessibilityFeatureClass: currentClass
        )
    }
    
    private func updateManager() throws {
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord,
              let captureMeshData = currentCaptureDataRecord as? (any CaptureMeshDataProtocol),
              let currentClass = currentClass
        else {
            throw AnnotationViewError.invalidCaptureDataRecord
        }
        try manager.update(
            captureImageData: currentCaptureDataRecord, captureMeshData: captureMeshData,
            accessibilityFeatureClass: currentClass
        )
    }
    
    private func confirmAnnotation() {
        if isCurrentIndexLast() {
            self.dismiss()
        }
        else {
            currentClassIndex += 1
        }
    }
    
    private func handleOnAppear() {
        do {
            try setCurrentClass()
            try configureManager()
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageSuffixKey)")
        }
    }
    
    private func handleOnIndexChange() {
        do {
            try setCurrentClass()
            try updateManager()
        } catch {
            managerStatusViewModel.update(
                isFailed: true,
                errorMessage: "\(error.localizedDescription) \(AnnotationViewConstants.Texts.managerStatusAlertMessageSuffixKey)")
        }
    }
}
