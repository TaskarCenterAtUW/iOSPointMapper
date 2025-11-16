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
    }
    
    enum Images {
        static let checkIcon = "checkmark"
        static let ellipsisIcon = "ellipsis"
        static let infoIcon = "info.circle"
        static let closeIcon = "xmark"
        static let errorIcon = "exclamationmark.triangle"
    }
}

struct AnnotationView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @Environment(\.dismiss) var dismiss
    
    @StateObject var manager: AnnotationImageManager = AnnotationImageManager()
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
                    setCurrentClass()
                    manager.configure(selectedClasses: selectedClasses)
                }
            } else {
                invalidPageView()
            }
        }
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
                        /// Finish annotation action
                    }) {
                        Text(AnnotationViewConstants.Texts.finishText)
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
            /// TODO: Replace this with proper error handling
            print("Current Capture Data Record is not of type CaptureImageData")
            return false
        }
        let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
        guard currentClassIndex >= 0 && currentClassIndex < segmentedClasses.count else {
            return false
        }
        return true
    }
    
    private func setCurrentClass() {
        guard isCurrentIndexValid() else {
            print("Current class index \(currentClassIndex) is out of bounds")
            return
        }
        guard let currentCaptureDataRecord = sharedAppData.currentCaptureDataRecord else {
            /// TODO: Replace this with proper error handling
            print("Current Capture Data Record is not of type CaptureImageData")
            return
        }
        let segmentedClasses = currentCaptureDataRecord.captureImageDataResults.segmentedClasses
        currentClass = segmentedClasses[currentClassIndex]
    }
}
