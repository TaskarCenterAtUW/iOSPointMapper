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
    let selectedClasses: [AccessibilityFeatureClass]
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @EnvironmentObject var segmentationPipeline: SegmentationARPipeline
    @EnvironmentObject var depthModel: DepthModel
    @Environment(\.dismiss) var dismiss
    
    @StateObject var objectLocation = ObjectLocation()

    @StateObject private var manager: ARCameraManager = ARCameraManager()
    @State private var managerConfigureStatusViewModel = ManagerStatusViewModel()
    @State private var managerCaptureStatusViewModel = ManagerStatusViewModel()
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait // To bind one-way with manager's orientation
    
    @State private var showAnnotationView = false
    
    var body: some View {
        Group {
            // Show the camera view once manager is initialized, otherwise a loading indicator
            if manager.isConfigured {
                orientationStack {
                    HostedARCameraViewContainer(arCameraManager: manager)
                    Button {
                        capture()
                    } label: {
                        Image(systemName: ARCameraViewConstants.Images.cameraIcon)
                            .resizable()
                            .frame(width: 60, height: 60)
                    }
                }
            } else {
                ProgressView(ARCameraViewConstants.Texts.cameraInProgressText)
            }
        }
        .navigationBarTitle(ARCameraViewConstants.Texts.contentViewTitle, displayMode: .inline)
        .onAppear {
            showAnnotationView = false
            segmentationPipeline.setSelectedClasses(selectedClasses)
            do {
                try manager.configure(selectedClasses: selectedClasses, segmentationPipeline: segmentationPipeline)
            } catch {
                managerConfigureStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
            }
        }
        .onDisappear {
        }
        .onReceive(manager.$interfaceOrientation) { newOrientation in
            interfaceOrientation = newOrientation
        }
        .alert(ARCameraViewConstants.Texts.managerStatusAlertTitleKey, isPresented: $managerConfigureStatusViewModel.isFailed, actions: {
            Button(ARCameraViewConstants.Texts.managerStatusAlertDismissButtonKey) {
                managerConfigureStatusViewModel.update(isFailed: false, errorMessage: "")
                dismiss()
            }
        }, message: {
            Text(managerConfigureStatusViewModel.errorMessage)
        })
        .alert(ARCameraViewConstants.Texts.managerStatusAlertTitleKey, isPresented: $managerConfigureStatusViewModel.isFailed, actions: {
            Button(ARCameraViewConstants.Texts.managerStatusAlertDismissButtonKey) {
                managerCaptureStatusViewModel.update(isFailed: false, errorMessage: "")
            }
        }, message: {
            Text(managerConfigureStatusViewModel.errorMessage)
        })
        .fullScreenCover(isPresented: $showAnnotationView) {
            AnnotationView(selectedClasses: selectedClasses)
        }
        .onChange(of: showAnnotationView, initial: false) { oldValue, newValue in
            // If the AnnotationView is dismissed, reconfigure the manager for a new session
            if (oldValue == true && newValue == false) {
                do {
                    try manager.reconfigure()
                } catch {
                    managerConfigureStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
                }
            }
        }
    }
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        interfaceOrientation.isLandscape ?
        AnyLayout(HStackLayout())(content) :
        AnyLayout(VStackLayout())(content)
    }
    
    private func capture() {
        Task {
            do {
                objectLocation.setLocationAndHeading()
                let captureData = try await manager.performFinalSessionUpdate()
                await sharedAppData.saveCaptureData(captureData)
                showAnnotationView = true
            } catch {
                managerCaptureStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
            }
        }
    }
}
