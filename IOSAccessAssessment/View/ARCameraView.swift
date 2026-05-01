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
import PointNMapShared

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
        static let cameraHintMappingDataNotReadyText = "Mapping Data Not Ready"
        
        /// Manager Status Alert
        static let managerStatusAlertTitleKey = "Error"
        static let managerStatusAlertDismissButtonKey = "OK"
        
        /// Mapping Data Status Alert
        static let mappingDataStatusAlertTitleKey = "Error"
        static let mappingDataStatusAlertRetryButtonKey = "Retry"
        static let mappingDataStatusAlertDismissButtonKey = "OK"
        
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
    case workspaceConfigurationFailed
    case authenticationError
    case mappingDataNotReady
    
    var errorDescription: String? {
        switch self {
        case .captureNoSegmentationAccessibilityFeatures:
            return "No accessibility features were captured. Please try again."
        case .workspaceConfigurationFailed:
            return "Workspace configuration failed. Please check your workspace settings."
        case .authenticationError:
            return "Authentication error. Please log in again."
        case .mappingDataNotReady:
            return "Mapping data is not ready yet. Please wait a moment and try again."
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

class MappingDataStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    @Published var isInProgress: Bool = false
    
    func update(isFailed: Bool, errorMessage: String) {
        self.isFailed = isFailed
        self.errorMessage = errorMessage
    }
    
    func update(isInProgress: Bool) {
        self.isInProgress = isInProgress
    }
}

struct ARCameraView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @EnvironmentObject var sharedAppContext: SharedAppContext
    @EnvironmentObject var segmentationPipeline: SegmentationARPipeline
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @Environment(\.dismiss) var dismiss

    @StateObject private var manager: ARCameraManager = ARCameraManager()
    @StateObject private var managerConfigureStatusViewModel = ARCameraManagerStatusViewModel()
    @State private var cameraHintText: String = ARCameraViewConstants.Texts.cameraHintPlaceholderText
    
    @StateObject private var locationManager: LocationManager = LocationManager()
//    @State private var captureLocation: CLLocationCoordinate2D?
//    @State private var captureHeading: CLLocationDirection?
    @StateObject private var mappingDataStatusViewModel = MappingDataStatusViewModel()
    
    @State private var showARCameraLearnMoreSheet = false
    
    @State private var showAnnotationView = false
    @StateObject private var apiChangesetUploadController: APIChangesetUploadController = APIChangesetUploadController()
    
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
            locationManager.startLocationUpdates()
            showAnnotationView = false
            segmentationPipeline.setSelectedClasses(selectedClasses)
            do {
                try manager.configure(
                    selectedClasses: selectedClasses, segmentationPipeline: segmentationPipeline,
                    metalContext: sharedAppContext.metalContext,
                    isEnhancedAnalysisEnabled: userStateViewModel.isEnhancedAnalysisEnabled,
                    cameraOutputImageCallback: cameraOutputImageCallback
                )
            } catch {
                managerConfigureStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
            }
        }
        .onDisappear {
            Task {
                do {
                    try manager.pause()
                    locationManager.stopLocationUpdates()
                } catch {
                    print("Error pausing ARCameraManager: \(error)")
                }
            }
        }
        .alert(ARCameraViewConstants.Texts.managerStatusAlertTitleKey, isPresented: $managerConfigureStatusViewModel.isFailed, actions: {
            Button(ARCameraViewConstants.Texts.managerStatusAlertDismissButtonKey) {
                managerConfigureStatusViewModel.update(isFailed: false, errorMessage: "")
                dismiss()
            }
        }, message: {
            Text(managerConfigureStatusViewModel.errorMessage)
        })
        .alert(ARCameraViewConstants.Texts.mappingDataStatusAlertTitleKey, isPresented: $mappingDataStatusViewModel.isFailed, actions: {
            Button(ARCameraViewConstants.Texts.mappingDataStatusAlertRetryButtonKey) {
                mappingDataStatusViewModel.update(isFailed: false, errorMessage: "")
                handleLocationUpdate(oldLocation: nil, newLocation: locationManager.currentLocation)
            }
            Button(ARCameraViewConstants.Texts.mappingDataStatusAlertDismissButtonKey) {
                mappingDataStatusViewModel.update(isFailed: false, errorMessage: "")
                dismiss()
            }
        }, message: {
            Text(mappingDataStatusViewModel.errorMessage)
        })
        .fullScreenCover(isPresented: $showAnnotationView) {
            if let captureLocation = locationManager.currentLocation?.coordinate {
                AnnotationView(
                    selectedClasses: selectedClasses, captureLocation: captureLocation,
                    apiChangesetUploadController: apiChangesetUploadController
                )
            } else {
                InvalidContentView(
                    title: ARCameraViewConstants.Texts.invalidContentViewTitle,
                    message: ARCameraViewConstants.Texts.invalidContentViewMessage
                )
            }
        }
        .onChange(of: showAnnotationView, initial: false) { oldValue, newValue in
            // If the AnnotationView is dismissed, clear capture history and reconfigure the manager for a new session
            Task {
                if (oldValue == true && newValue == false) {
                    do {
                        locationManager.startLocationUpdates()
                        await sharedAppData.refreshQueue()
                        try manager.resume()
                    } catch {
                        managerConfigureStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
                    }
                }
            }
        }
        .onChange(of: manager.interfaceOrientation) { oldOrientation, newOrientation in
            locationManager.updateOrientation(newOrientation)
        }
        .onChange(of: locationManager.currentLocation) { oldLocation, newLocation in
            handleLocationUpdate(oldLocation: oldLocation, newLocation: newLocation)
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
                guard !mappingDataStatusViewModel.isInProgress else {
                    throw ARCameraViewError.mappingDataNotReady
                }
                let captureData: CaptureData = try await manager.performFinalSessionUpdateIfPossible()
                switch captureData {
                case .imageData(let data):
                    if (data.captureImageDataResults.segmentedClasses.isEmpty)
                    {
                        throw ARCameraViewError.captureNoSegmentationAccessibilityFeatures
                    }
                case .imageAndMeshData(let data):
                    if (data.captureImageDataResults.segmentedClasses.isEmpty)
                    || (data.captureMeshDataResults.segmentedMesh.totalVertexCount == 0)
                    {
                        throw ARCameraViewError.captureNoSegmentationAccessibilityFeatures
                    }
                default: break
                }
                try manager.pause()
                locationManager.stopLocationUpdates()
                /// Get location. Done after pausing the manager to avoid delays, despite being less accurate.
                sharedAppData.saveCaptureData(captureData)
                addCaptureDataToCurrentDataset(
                    captureImageData: captureData.imageData, captureMeshData: captureData.meshData,
                    location: locationManager.currentLocation?.coordinate, heading: locationManager.currentHeading?.trueHeading
                )
                showAnnotationView = true
            } catch ARCameraManagerError.finalSessionMeshUnavailable {
                setHintText(ARCameraViewConstants.Texts.cameraHintNoMeshText)
            } catch ARCameraManagerError.finalSessionNoSegmentationClass,
                ARCameraViewError.captureNoSegmentationAccessibilityFeatures {
                setHintText(ARCameraViewConstants.Texts.cameraHintNoSegmentationText)
            } catch ARCameraManagerError.finalSessionNoSegmentationMesh {
                setHintText(ARCameraViewConstants.Texts.cameraHintMeshNotProcessedText)
            } catch ARCameraViewError.mappingDataNotReady {
                setHintText(ARCameraViewConstants.Texts.cameraHintMappingDataNotReadyText)
            } catch _ as LocationManagerError {
                setHintText(ARCameraViewConstants.Texts.cameraHintLocationErrorText)
            } catch {
                setHintText(ARCameraViewConstants.Texts.cameraHintUnknownErrorText)
            }
        }
    }
    
    private func addCaptureDataToCurrentDataset(
        captureImageData: any CaptureImageDataProtocol,
        captureMeshData: (any CaptureMeshDataProtocol)? = nil,
        location: CLLocationCoordinate2D?,
        heading: CLLocationDirection?
    ) {
        Task {
            do {
                try sharedAppData.currentDatasetEncoder?.addCaptureData(
                    captureImageData: captureImageData,
                    captureMeshData: captureMeshData,
                    location: locationManager.currentLocation?.coordinate,
                    heading: locationManager.currentHeading?.trueHeading
                )
            } catch {
                print("Error adding capture data to dataset encoder: \(error)")
            }
        }
    }
    
    private func handleLocationUpdate(oldLocation: CLLocation?, newLocation: CLLocation?) {
        var shouldUpdateMap = oldLocation == nil && newLocation != nil
        if let oldLocation, let newLocation {
            let distance = oldLocation.distance(from: newLocation)
            shouldUpdateMap = distance > SharedAppConstants.WorkspaceConstants.fetchUpdateRadiusThresholdInMeters
        }
        if !shouldUpdateMap {
            return
        }
        Task {
            do {
                mappingDataStatusViewModel.update(isInProgress: true)
                guard let workspaceId = workspaceViewModel.workspaceId,
                      let location = newLocation?.coordinate else {
                    throw ARCameraViewError.workspaceConfigurationFailed
                }
                guard let accessToken = userStateViewModel.getAccessToken() else {
                    throw ARCameraViewError.authenticationError
                }
                let mapData = try await WorkspaceService.shared.fetchMapData(
                    workspaceId: workspaceId,
                    location: location,
                    radius: SharedAppConstants.WorkspaceConstants.fetchRadiusInMeters,
                    accessToken: accessToken,
                    environment: userStateViewModel.selectedEnvironment
                )
                sharedAppData.currentMappingData.replace(
                    osmMapDataResponse: mapData,
                    accessibilityFeatureClasses: selectedClasses
                )
                mappingDataStatusViewModel.update(isInProgress: false)
            } catch {
                mappingDataStatusViewModel.update(isInProgress: false)
                mappingDataStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
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
