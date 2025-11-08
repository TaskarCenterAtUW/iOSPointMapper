//
//  ARCameraView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
import AVFoundation
import Vision
import Metal
import CoreImage
import MetalKit

enum ARCameraViewConstants {
    enum Texts {
        static let contentViewTitle = "Capture"
        
        static let cameraInProgressText = "Camera settings in progress"
        
        // Manager Status Alert
        static let managerStatusAlertTitleKey = "Error"
        static let managerStatusAlertDismissButtonKey = "OK"
    }
    
    enum Images {
        static let cameraIcon = "camera.circle.fill"
        
    }
    
    enum Colors {
        static let selectedClass = Color(red: 187/255, green: 134/255, blue: 252/255)
        static let unselectedClass = Color.primary
    }
    
    enum Constraints {
        static let logoutIconSize: CGFloat = 20
    }
}

class ManagerStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    
    func update(isFailed: Bool, errorMessage: String) {
        objectWillChange.send()
        
        self.isFailed = isFailed
        self.errorMessage = errorMessage
    }
}

struct ARCameraView: View {
    let selection: [Int]
    
    @EnvironmentObject var sharedImageData: SharedImageData
    @EnvironmentObject var segmentationPipeline: SegmentationARPipeline
    @EnvironmentObject var segmentationMeshPiepline: SegmentationMeshPipeline
    @EnvironmentObject var depthModel: DepthModel
    @Environment(\.dismiss) var dismiss
    
    @StateObject var objectLocation = ObjectLocation()

    @StateObject private var manager: ARCameraManager = ARCameraManager()
    @State private var managerStatusViewModel = ManagerStatusViewModel()
    
    @State private var navigateToAnnotationView = false
    
    var body: some View {
        Group {
            // Show the camera view once manager is initialized, otherwise a loading indicator
            if manager.isConfigured {
                HostedARCameraViewContainer(arCameraManager: manager)
            } else {
                ProgressView(ARCameraViewConstants.Texts.cameraInProgressText)
            }
        }
        .navigationBarTitle(ARCameraViewConstants.Texts.contentViewTitle, displayMode: .inline)
        .onAppear {
            navigateToAnnotationView = false
            
            segmentationPipeline.setSelectionClasses(selection)
            segmentationMeshPiepline.setSelectionClasses(selection)
//                segmentationPipeline.setCompletionHandler(segmentationPipelineCompletionHandler)
            do {
                try manager.configure(
                    selection: selection,
                    segmentationPipeline: segmentationPipeline, segmentationMeshPipeline: segmentationMeshPiepline
                )
            } catch {
                managerStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
            }
        }
        .onDisappear {
        }
        .alert(ARCameraViewConstants.Texts.managerStatusAlertTitleKey, isPresented: $managerStatusViewModel.isFailed, actions: {
            Button(ARCameraViewConstants.Texts.managerStatusAlertDismissButtonKey) {
                dismiss()
            }
        }, message: {
            Text(managerStatusViewModel.errorMessage)
        })
//        .navigationDestination(isPresented: $navigateToAnnotationView) {
//            AnnotationView(
//                selection: selection,
//                objectLocation: objectLocation
//            )
//        }
    }
}
