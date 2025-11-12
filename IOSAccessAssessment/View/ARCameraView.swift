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
        
        /// Camera Hint Texts
        static let cameraHintPlaceholderText = "..."
        static let cameraHintMeshNotProcessedText = "Mesh Not Processed"
        static let cameraHintNoSegmentationText = "No Features Detected"
        static let cameraHintUnknownErrorText = "Unknown Error"
        
        /// Manager Status Alert
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

enum ARCameraViewError: Error, LocalizedError {
    case captureNoSegmentationAccessibilityFeatures
    
    var errorDescription: String? {
        switch self {
        case .captureNoSegmentationAccessibilityFeatures:
            return "No accessibility features were captured. Please try again."
        }
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
    @State private var interfaceOrientation: UIInterfaceOrientation = .portrait // To bind one-way with manager's orientation
    @State private var cameraHintText: String = ARCameraViewConstants.Texts.cameraHintPlaceholderText
    
    @State private var showAnnotationView = false
    
    var body: some View {
        Group {
            // Show the camera view once manager is initialized, otherwise a loading indicator
            if manager.isConfigured {
                orientationStack {
                    HostedARCameraViewContainer(arCameraManager: manager)
                    VStack {
                        /// Text for hinting user with status
                        Text(cameraHintText)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: 300)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        Button {
                            capture()
                        } label: {
                            Image(systemName: ARCameraViewConstants.Images.cameraIcon)
                                .resizable()
                                .frame(width: 60, height: 60)
                        }
                        .padding(.bottom, 20)
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
        .fullScreenCover(isPresented: $showAnnotationView) {
            AnnotationView(selectedClasses: selectedClasses)
        }
        .onChange(of: showAnnotationView, initial: false) { oldValue, newValue in
            // If the AnnotationView is dismissed, reconfigure the manager for a new session
            if (oldValue == true && newValue == false) {
                do {
                    try manager.resume()
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
                if captureData.captureDataResults.segmentedClasses.isEmpty {
                    throw ARCameraViewError.captureNoSegmentationAccessibilityFeatures
                }
                try manager.pause()
                await sharedAppData.saveCaptureData(captureData)
                showAnnotationView = true
            } catch ARCameraManagerError.finalSessionMeshUnavailable {
                setHintText(ARCameraViewConstants.Texts.cameraHintMeshNotProcessedText)
            } catch _ as ARCameraViewError {
                setHintText(ARCameraViewConstants.Texts.cameraHintNoSegmentationText)
            } catch {
                setHintText(ARCameraViewConstants.Texts.cameraHintUnknownErrorText)
            }
        }
    }
    
    /// Set text for 2 seconds, and then fall back to placeholder
    private func setHintText(_ text: String) {
        cameraHintText = text
        Task {
            try await Task.sleep(for: .seconds(2))
            cameraHintText = ARCameraViewConstants.Texts.cameraHintPlaceholderText
        }
    }
}
