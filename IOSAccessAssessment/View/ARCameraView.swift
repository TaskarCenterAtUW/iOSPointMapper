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
import CoreLocation

enum ARCameraViewConstants {
    enum Texts {
        static let contentViewTitle = "Capture"
        
        static let cameraInProgressText = "Camera settings in progress"
        
        /// Camera Hint Texts
        static let cameraHintPlaceholderText = "..."
        static let cameraHintNoMeshText = "No Mesh Captured"
        static let cameraHintNoSegmentationText = "No Features Detected"
        static let cameraHintMeshNotProcessedText = "Features Not Processed"
        static let cameraHintLocationErrorText = "Location Error"
        static let cameraHintUnknownErrorText = "Unknown Error"
        
        /// Manager Status Alert
        static let managerStatusAlertTitleKey = "Error"
        static let managerStatusAlertDismissButtonKey = "OK"
        
        /// Invalid Content View
        static let invalidContentViewTitle = "Invalid Capture"
        static let invalidContentViewMessage = "The captured data is invalid. Please try again."
        
        /// ARCameraLearnMoreSheetView
        static let arCameraLearnMoreSheetTitle = "About Capture"
        static let arCameraLearnMoreSheetMessage = """
        Use this screen to capture accessibility features in your environment. 
        
        Point your device's camera at the area you want to capture, and press the Camera Button to take a snapshot.
        
        After capturing, you will be prompted to validate the annotated features.
        """
    }
    
    enum Images {
        static let cameraIcon = "camera.circle.fill"
        
        /// InfoTio
        static let infoIcon = "info.circle"
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

class ARCameraManagerStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    
    func update(isFailed: Bool, errorMessage: String) {        
        self.isFailed = isFailed
        self.errorMessage = errorMessage
    }
}

struct ARCameraView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @EnvironmentObject var sharedAppContext: SharedAppContext
    @EnvironmentObject var segmentationPipeline: SegmentationARPipeline
    @Environment(\.dismiss) var dismiss

    @StateObject private var manager: ARCameraManager = ARCameraManager()
    @StateObject private var managerConfigureStatusViewModel = ARCameraManagerStatusViewModel()
    @State private var cameraHintText: String = ARCameraViewConstants.Texts.cameraHintPlaceholderText
    
    var locationManager: LocationManager = LocationManager()
    @State private var captureLocation: CLLocationCoordinate2D?
    
    @State private var showARCameraLearnMoreSheet = false
    
    @State private var showAnnotationView = false
    
    var body: some View {
        Group {
            // Show the camera view once manager is initialized, otherwise a loading indicator
            if manager.isConfigured {
                orientationStack {
                    HostedARCameraViewContainer(arSessionCameraProcessingDelegate: manager)
                    VStack {
                        /// Text for hinting user with status
                        Text(cameraHintText)
                            .padding()
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: 300)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        reverseOrientationStack {
                            Spacer()
                            Button {
                                cameraCapture()
                            } label: {
                                Image(systemName: ARCameraViewConstants.Images.cameraIcon)
                                    .resizable()
                                    .frame(width: 60, height: 60)
                            }
                            .padding(.bottom, 20)
                            Spacer()
                        }
                        .overlay(
                            reverseOrientationStack {
                                Spacer()
                                Button(action: {
                                    showARCameraLearnMoreSheet = true
                                }) {
                                    Image(systemName: ARCameraViewConstants.Images.infoIcon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        )
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
                try manager.configure(
                    selectedClasses: selectedClasses, segmentationPipeline: segmentationPipeline,
                    metalContext: sharedAppContext.metalContext,
                    cameraOutputImageCallback: cameraOutputImageCallback
                )
            } catch {
                managerConfigureStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
            }
        }
        .onDisappear {
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
            if let captureLocation {
                AnnotationView(selectedClasses: selectedClasses, captureLocation: captureLocation)
            } else {
                InvalidContentView(
                    title: ARCameraViewConstants.Texts.invalidContentViewTitle,
                    message: ARCameraViewConstants.Texts.invalidContentViewMessage
                )
            }
        }
        .onChange(of: showAnnotationView, initial: false) { oldValue, newValue in
            // If the AnnotationView is dismissed, reconfigure the manager for a new session
            if (oldValue == true && newValue == false) {
                do {
                    captureLocation = nil
                    try manager.resume()
                } catch {
                    managerConfigureStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
                }
            }
        }
        .sheet(isPresented: $showARCameraLearnMoreSheet) {
            ARCameraLearnMoreSheetView()
                .presentationDetents([.medium, .large])
        }
    }
    
    @ViewBuilder
    private func orientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        manager.interfaceOrientation.isLandscape ?
        AnyLayout(HStackLayout())(content) :
        AnyLayout(VStackLayout())(content)
    }
    
    @ViewBuilder
    private func reverseOrientationStack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        manager.interfaceOrientation.isLandscape ?
        AnyLayout(VStackLayout())(content) :
        AnyLayout(HStackLayout())(content)
    }
    
    private func cameraOutputImageCallback(_ captureImageData: (any CaptureImageDataProtocol)) {
        Task {
            await sharedAppData.appendCaptureDataToQueue(captureImageData)
        }
    }
    
    private func cameraCapture() {
        Task {
            do {
                let captureData = try await manager.performFinalSessionUpdateIfPossible()
                if (captureData.captureImageDataResults.segmentedClasses.isEmpty) ||
                    (captureData.captureMeshDataResults.segmentedMesh.totalVertexCount == 0) {
                    throw ARCameraViewError.captureNoSegmentationAccessibilityFeatures
                }
                captureLocation = try locationManager.getLocationCoordinate()
                try manager.pause()
                /// Get location. Done after pausing the manager to avoid delays, despite being less accurate.
                sharedAppData.saveCaptureData(captureData)
                addCaptureDataToCurrentDataset(captureImageData: captureData, location: captureLocation)
                showAnnotationView = true
            } catch ARCameraManagerError.finalSessionMeshUnavailable {
                setHintText(ARCameraViewConstants.Texts.cameraHintNoMeshText)
            } catch ARCameraManagerError.finalSessionNoSegmentationClass,
                ARCameraViewError.captureNoSegmentationAccessibilityFeatures {
                setHintText(ARCameraViewConstants.Texts.cameraHintNoSegmentationText)
            } catch ARCameraManagerError.finalSessionNoSegmentationMesh {
                setHintText(ARCameraViewConstants.Texts.cameraHintMeshNotProcessedText)
            } catch _ as LocationManagerError {
                setHintText(ARCameraViewConstants.Texts.cameraHintLocationErrorText)
            } catch {
                setHintText(ARCameraViewConstants.Texts.cameraHintUnknownErrorText)
            }
        }
    }
    
    private func addCaptureDataToCurrentDataset(
        captureImageData: any CaptureImageDataProtocol,
        location: CLLocationCoordinate2D?
    ) {
        do {
            try sharedAppData.currentDatasetEncoder?.addCaptureData(
                captureImageData: captureImageData,
                location: captureLocation
            )
        } catch {
            print("Error adding capture data to dataset encoder: \(error)")
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

struct ARCameraLearnMoreSheetView: View {
    @Environment(\.dismiss)
    var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
//            Image(systemName: "number")
//                .resizable()
//                .scaledToFit()
//                .frame(width: 160)
//                .foregroundStyle(.accentColor)
            Text(ARCameraViewConstants.Texts.arCameraLearnMoreSheetTitle)
                .font(.headline)
            Text(ARCameraViewConstants.Texts.arCameraLearnMoreSheetMessage)
            .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}
