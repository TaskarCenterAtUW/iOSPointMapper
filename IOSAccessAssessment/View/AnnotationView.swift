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
        
        static let selectedClassPrefixText = "Selected class: "
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
    
    @State var index = 0
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text(AnnotationViewConstants.Texts.annotationViewTitle)
                    .font(.title)
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
                orientationStack {
                    HostedAnnotationCameraViewController()
                    
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(AnnotationViewConstants.Texts.selectedClassPrefixText)")
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
                            /// Annotation Options
                            Spacer()
                        }
                        .padding()
                        
                        Button(action: {
                            // Finish annotation action
                        }) {
                            Text(AnnotationViewConstants.Texts.finishText)
                                .padding()
                        }
                    }
                }
            } else {
                VStack {
                    Label {
                        Text(AnnotationViewConstants.Texts.invalidPageText)
                    } icon: {
                        Image(systemName: AnnotationViewConstants.Images.errorIcon)
                    }
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
//        interfaceOrientation.isLandscape ?
//        AnyLayout(HStackLayout())(content) :
        AnyLayout(VStackLayout())(content)
    }
    
    private func isCurrentIndexValid() -> Bool {
        return false
        let segmentedClasses = sharedAppData.currentCaptureDataRecord?.captureDataResults.segmentedClasses ?? []
        guard index >= 0 && index < segmentedClasses.count else {
            return false
        }
        return true
    }
}
