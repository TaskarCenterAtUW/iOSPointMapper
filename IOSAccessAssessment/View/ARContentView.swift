//
//  ARContentView.swift
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

enum ARContentViewConstants {
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

struct ARContentView: View {
    var selection: [Int]
    
    @EnvironmentObject var sharedImageData: SharedImageData
    @EnvironmentObject var segmentationPipeline: SegmentationARPipeline
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
                ProgressView(ARContentViewConstants.Texts.cameraInProgressText)
            }
        }
        .navigationDestination(isPresented: $navigateToAnnotationView) {
            AnnotationView(
                selection: selection,
                objectLocation: objectLocation
            )
        }
        .navigationBarTitle(ARContentViewConstants.Texts.contentViewTitle, displayMode: .inline)
        .onAppear {
            navigateToAnnotationView = false
            
            segmentationPipeline.setSelectionClasses(selection)
//                segmentationPipeline.setCompletionHandler(segmentationPipelineCompletionHandler)
            do {
                try manager.configure(segmentationPipeline: segmentationPipeline)
            } catch {
                managerStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
            }
        }
        .onDisappear {
        }
        .alert(ARContentViewConstants.Texts.managerStatusAlertTitleKey, isPresented: $managerStatusViewModel.isFailed, actions: {
            Button(ARContentViewConstants.Texts.managerStatusAlertDismissButtonKey) {
                dismiss()
            }
        }, message: {
            Text(managerStatusViewModel.errorMessage)
        })
    }
}
