//
//  TestView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import SwiftUI
import CoreLocation

/**
 Additional constants unique to TestCameraView (not used in ARCameraView)
 */
enum TestCameraViewConstants {
    enum Texts {
        static let contentViewTitle = "Test: Capture"
        
        /// Camera Hint Texts
        static let cameraHintPlaceholderText = "..."
        
        /// ARCameraLearnMoreSheetView
        static let testCameraLearnMoreSheetTitle = "About Capture"
        static let testCameraLearnMoreSheetMessage = """
        Use this screen to simulate capturing of accessibility features in your environment using local data. 
        
        Select the desired image, and press the Camera Button to take a snapshot.
        
        After capturing, you will be prompted to validate the annotated features.
        """
    }
}

enum TestCameraViewError: Error, LocalizedError {
    case captureDataUnavailable
    case captureNoSegmentationAccessibilityFeatures
    
    var errorDescription: String? {
        switch self {
        case .captureDataUnavailable:
            return "Capture data is unavailable. Please try again."
        case .captureNoSegmentationAccessibilityFeatures:
            return "No accessibility features were captured. Please try again."
        }
    }
}

/**
 TestCameraView uses the data saved in the changeset directory, to simulate mapping
 */
struct TestCameraView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    let workspaceId: String
    let changesetId: String
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @EnvironmentObject var sharedAppContext: SharedAppContext
    @EnvironmentObject var segmentationPipeline: SegmentationARPipeline
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var manager: TestCameraManager = TestCameraManager()
    @StateObject private var managerConfigureStatusViewModel = ARCameraManagerStatusViewModel()
    @State private var cameraHintText: String = ARCameraViewConstants.Texts.cameraHintPlaceholderText
    
//    var locationManager: LocationManager = LocationManager()
//    @State private var captureLocation: CLLocationCoordinate2D?
    
    @State private var showARCameraLearnMoreSheet = false
    
    @State private var showAnnotationView = false
    
    // Latest dataset capture data
    @State private var datasetCaptureData: DatasetCaptureData?
    @State private var currentIndex: Int = 0
    
    var body: some View {
        VStack {
            if manager.isConfigured {
                orientationStack {
                    HostedTestCameraViewContainer(arSessionCameraProcessingDelegate: manager)
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
            }
            else {
                ProgressView(ARCameraViewConstants.Texts.cameraInProgressText)
            }
        }
        .navigationBarTitle(TestCameraViewConstants.Texts.contentViewTitle, displayMode: .inline)
        .onAppear {
            showAnnotationView = false
            segmentationPipeline.setSelectedClasses(selectedClasses)
            do {
                let datasetDecoder = try initializeDatasetDecoder()
                let datasetCaptureData = try loadData(datasetDecoder: datasetDecoder)
                sharedAppData.currentDatasetDecoder = datasetDecoder
                self.datasetCaptureData = datasetCaptureData
                try manager.configure(
                    selectedClasses: selectedClasses, segmentationPipeline: segmentationPipeline,
                    metalContext: sharedAppContext.metalContext,
                    cameraOutputImageCallback: cameraOutputImageCallback
                )
                try manager.handleSessionFrameUpdate(datasetCaptureData: datasetCaptureData)
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
//        .fullScreenCover(isPresented: $showAnnotationView) {
//            if let captureLocation {
//                AnnotationView(selectedClasses: selectedClasses, captureLocation: captureLocation)
//            } else {
//                InvalidContentView(
//                    title: ARCameraViewConstants.Texts.invalidContentViewTitle,
//                    message: ARCameraViewConstants.Texts.invalidContentViewMessage
//                )
//            }
//        }
        .onChange(of: showAnnotationView, initial: false) { oldValue, newValue in
            // If the AnnotationView is dismissed, reconfigure the manager for a new session
//            if (oldValue == true && newValue == false) {
//                do {
////                    captureLocation = nil
////                    try manager.resume()
//                } catch {
//                    managerConfigureStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
//                }
//            }
        }
        .sheet(isPresented: $showARCameraLearnMoreSheet) {
            ARCameraLearnMoreSheetView()
                .presentationDetents([.medium, .large])
        }
    }
    
    private func initializeDatasetDecoder() throws -> DatasetDecoder {
        return try DatasetDecoder(workspaceId: workspaceId, changesetId: changesetId)
    }
    
    private func loadData(datasetDecoder: DatasetDecoder) throws -> DatasetCaptureData {
        let datasetCaptureData = try datasetDecoder.loadData(index: currentIndex)
        return datasetCaptureData
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
                guard let datadatasetCaptureData = datasetCaptureData else {
                    throw TestCameraViewError.captureDataUnavailable
                }
                let captureData: CaptureData = try await manager.performFinalSessionUpdateIfPossible()
                switch captureData {
                case .imageData(let data):
                    if (data.captureImageDataResults.segmentedClasses.isEmpty)
                    {
                        throw TestCameraViewError.captureNoSegmentationAccessibilityFeatures
                    }
                case .imageAndMeshData(let data):
                    if (data.captureImageDataResults.segmentedClasses.isEmpty)
                    || (data.captureMeshDataResults.segmentedMesh.totalVertexCount == 0)
                    {
                        throw TestCameraViewError.captureNoSegmentationAccessibilityFeatures
                    }
                }
                let captureLocation = datadatasetCaptureData.location
                try manager.pause()
                /// Get location. Done after pausing the manager to avoid delays, despite being less accurate.
                sharedAppData.saveCaptureData(captureData)
                addCaptureDataToCurrentDataset(
                    captureImageData: captureData.imageData, captureMeshData: captureData.meshData, location: captureLocation
                )
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
        captureMeshData: (any CaptureMeshDataProtocol)? = nil,
        location: CLLocationCoordinate2D?
    ) {
        Task {
            do {
                try sharedAppData.currentDatasetEncoder?.addCaptureData(
                    captureImageData: captureImageData,
                    captureMeshData: captureMeshData,
                    location: location
                )
            } catch {
                print("Error adding capture data to dataset encoder: \(error)")
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
