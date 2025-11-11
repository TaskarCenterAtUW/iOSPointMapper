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
        
        static let selectObjectText = "Select an object"
        static let selectAllLabelText = "Select All"
        
        static let confirmAnnotationFailedTitle = "Cannot confirm annotation"
        static let depthOrSegmentationUnavailableText = "Depth or segmentation related information is not available." +
        "\nDo you want to upload all the objects as a single point with the current location?"
        static let confirmAnnotationFailedConfirmText = "Yes"
        static let confirmAnnotationFailedCancelText = "No"
        
        static let uploadFailedTitle = "Upload Failed"
        static let uploadFailedMessage = "Failed to upload the annotated data. Please try again."
        
        // Upload status messages
        static let discardingAllObjectsMessage = "Discarding all objects"
        static let noObjectsToUploadMessage = "No objects to upload"
        static let workspaceIdNilMessage = "Workspace ID is nil"
        static let apiFailedMessage = "API failed"
        
        static let selectCorrectAnnotationText = "Select correct annotation"
        static let doneText = "Done"
        
        // SelectObjectInfoTip
        static let selectObjectInfoTipTitle = "Select an Object"
        static let selectObjectInfoTipMessage = "Please select the object that you want to annotate individually"
        static let selectObjectInfoTipLearnMoreButtonTitle = "Learn More"
        
        // SelectObjectInfoLearnMoreSheetView
        static let selectObjectInfoLearnMoreSheetTitle = "Annotating an Object"
        static let selectObjectInfoLearnMoreSheetMessage = """
        For each class/type of object, the app can identify multiple instances within the same image. 
        
        **Select All**: Default option; you can annotate all instances of a particular class/type together.
        
        **Individual**: You can select a particular object from the dropdown menu if you wish to provide specific annotations for individual instances.
        
        **Ellipsis [...]**: For each object, you can also view its details by tapping the ellipsis button next to the dropdown menu.
        """
    }
    
    enum Images {
        static let checkIcon = "checkmark"
        static let ellipsisIcon = "ellipsis"
        static let infoIcon = "info.circle"
        static let closeIcon = "xmark"
    }
}

struct AnnotationView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @Environment(\.dismiss) var dismiss
    
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
        }
    }
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
//        interfaceOrientation.isLandscape ?
//        AnyLayout(HStackLayout())(content) :
        AnyLayout(VStackLayout())(content)
    }
}
