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
        
        /// Change index buttons
        static let previousButtonText = "Previous"
        static let nextButtonText = "Next"
        
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
    
    enum Images {
        static let previousIcon = "arrow.left.circle"
        static let nextIcon = "arrow.right.circle"
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

@MainActor
class LocationManagerPlaceholder: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var currentHeading: CLHeading?
    
    override init() {
        super.init()
    }
    
    func startLocationUpdates() {}
    
    private func setupLocationManager() {}
    
    /**
    Updates the heading orientation of the location manager based on the current device orientation. This ensures that heading data is accurate and consistent with the user's perspective.
     */
    public func updateOrientation(_ orientation: UIInterfaceOrientation) {}
    
    func locationManager(didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        guard let horizontalAccuracy = latestLocation.horizontalAccuracy as CLLocationAccuracy?,
                let verticalAccuracy = latestLocation.verticalAccuracy as CLLocationAccuracy?,
              horizontalAccuracy > 0, verticalAccuracy > 0 else {
            return
        }
        Task { @MainActor in
            self.currentLocation = latestLocation
        }
    }
    
    func locationManager(didUpdateHeading newHeading: CLHeading) {
        guard let headingAccuracy = newHeading.headingAccuracy as CLLocationDirection?,
              headingAccuracy > 0 else {
            return
        }
        Task { @MainActor in
            self.currentHeading = newHeading
        }
    }
    
    func stopLocationUpdates() {}

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
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var manager: TestCameraManager = TestCameraManager()
    @StateObject private var managerConfigureStatusViewModel = ARCameraManagerStatusViewModel()
    @State private var cameraHintDefaultText: String = ARCameraViewConstants.Texts.cameraHintPlaceholderText
    @State private var cameraHintText: String = ARCameraViewConstants.Texts.cameraHintPlaceholderText
    
    var locationManager: LocationManagerPlaceholder = LocationManagerPlaceholder()
//    @State private var captureLocation: CLLocationCoordinate2D?
//    @State private var captureHeading: CLLocationDirection?
    @StateObject private var mappingDataStatusViewModel = MappingDataStatusViewModel()
    
    @State private var showARCameraLearnMoreSheet = false
    
    @State private var showAnnotationView = false
    @StateObject private var apiChangesetUploadController: APIChangesetUploadController = APIChangesetUploadController()
    
    // Latest dataset capture data
    @State private var datasetCaptureData: DatasetCaptureData?
    @State private var currentIndex: Int = 0
    @State private var totalCaptures: Int = 0
    
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
                            Button {
                                self.currentIndex = max(self.currentIndex - 1, 0)
                            } label: {
                                Image(systemName: TestCameraViewConstants.Images.previousIcon)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                            }
                            .padding(.leading, 20)
                            .padding(.bottom, 20)
                            .disabled(currentIndex == 0)
                            Spacer()
                            Button {
                                cameraCapture()
                            } label: {
//                                Image(systemName: ARCameraViewConstants.Images.cameraIcon)
//                                    .resizable()
//                                    .frame(width: 60, height: 60)
                                Text("\(self.currentIndex)")
                                    .frame(width: 60, height: 60)
    //                                .foregroundColor(.white)
                                    .border(Color.black, width: 2)
                            }
                            .padding(.bottom, 20)
                            Spacer()
                            Button {
                                /// TODO: Find the total number of captures in the dataset and disable the button accordingly
                                self.currentIndex = max(min(self.currentIndex + 1, self.totalCaptures - 1), 0)
                            } label: {
                                Image(systemName: TestCameraViewConstants.Images.nextIcon)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 20)
                            .disabled(currentIndex >= totalCaptures - 1)
                        }
//                        .overlay(
//                            reverseOrientationStack {
//                                Spacer()
//                                Button(action: {
//                                    showARCameraLearnMoreSheet = true
//                                }) {
//                                    Image(systemName: ARCameraViewConstants.Images.infoIcon)
//                                        .resizable()
//                                        .frame(width: 20, height: 20)
//                                }
//                                .padding(.horizontal, 20)
//                                .padding(.bottom, 20)
//                            }
//                        )
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
                self.totalCaptures = datasetDecoder.totalFrames
                let datasetCaptureData = try loadData(
                    datasetDecoder: datasetDecoder, enhancedAnalysisMode: userStateViewModel.isEnhancedAnalysisEnabled
                )
                sharedAppData.currentDatasetDecoder = datasetDecoder
                self.datasetCaptureData = datasetCaptureData
                if let captureLocation = datasetCaptureData.location {
                    self.locationManager.locationManager(didUpdateLocations: [
                        CLLocation(latitude: captureLocation.latitude, longitude: captureLocation.longitude)
                    ])
                }
                if let captureHeading = datasetCaptureData.heading {
                    let heading = CLHeading()
                    heading.setValue(captureHeading, forKey: "trueHeading")
                    self.locationManager.locationManager(didUpdateHeading: heading)
                }
                try manager.configure(
                    selectedClasses: selectedClasses, segmentationPipeline: segmentationPipeline,
                    metalContext: sharedAppContext.metalContext,
                    isEnhancedAnalysisEnabled: userStateViewModel.isEnhancedAnalysisEnabled,
                    cameraOutputImageCallback: cameraOutputImageCallback
                )
                manager.handleSessionUpdate(datasetCaptureData: datasetCaptureData)
                
                /// For easier testing
                cameraHintDefaultText = datasetCaptureData.captureImageData.id.uuidString
                setHintText(datasetCaptureData.captureImageData.id.uuidString)
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
            // If the AnnotationView is dismissed, clear capture history and move to the next capture data
            Task {
                if (oldValue == true && newValue == false) {
                    await sharedAppData.refreshQueue()
                    self.currentIndex = max(min(self.currentIndex + 1, self.totalCaptures - 1), 0)
                }
            }
        }
//        .onChange(of: manager.interfaceOrientation) { oldOrientation, newOrientation in
//            locationManager.updateOrientation(newOrientation)
//        }
        .onChange(of: locationManager.currentLocation) { oldLocation, newLocation in
            handleLocationUpdate(oldLocation: oldLocation, newLocation: newLocation)
        }
        .onChange(of: currentIndex) { oldValue, newValue in
            do {
                guard let datasetDecoder = sharedAppData.currentDatasetDecoder else {
                    throw TestCameraViewError.captureDataUnavailable
                }
                let datasetCaptureData = try loadData(
                    datasetDecoder: datasetDecoder, enhancedAnalysisMode: userStateViewModel.isEnhancedAnalysisEnabled
                )
                self.datasetCaptureData = datasetCaptureData
                if let captureLocation = datasetCaptureData.location {
                    self.locationManager.locationManager(didUpdateLocations: [
                        CLLocation(latitude: captureLocation.latitude, longitude: captureLocation.longitude)
                    ])
                }
                if let captureHeading = datasetCaptureData.heading {
                    let heading = CLHeading()
                    heading.setValue(captureHeading, forKey: "trueHeading")
                    self.locationManager.locationManager(didUpdateHeading: heading)
                }
                
                manager.handleSessionUpdate(datasetCaptureData: datasetCaptureData)
                
                /// For easier testing
                cameraHintDefaultText = datasetCaptureData.captureImageData.id.uuidString
                setHintText(datasetCaptureData.captureImageData.id.uuidString)
            } catch {
                managerConfigureStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
            }
        }
        .sheet(isPresented: $showARCameraLearnMoreSheet) {
            ARCameraLearnMoreSheetView()
                .presentationDetents([.medium, .large])
        }
    }
    
    private func initializeDatasetDecoder() throws -> DatasetDecoder {
        return try DatasetDecoder(workspaceId: workspaceId, changesetId: changesetId)
    }
    
    private func loadData(datasetDecoder: DatasetDecoder, enhancedAnalysisMode: Bool) throws -> DatasetCaptureData {
        let datasetCaptureData = try datasetDecoder.loadData(index: currentIndex, enhancedAnalysisMode: enhancedAnalysisMode)
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
        // We do not need capture history in this test flow.
//        Task {
//            await sharedAppData.appendCaptureDataToQueue(captureImageData)
//        }
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
                let captureHeading = datadatasetCaptureData.heading
                try manager.pause()
                /// Get location. Done after pausing the manager to avoid delays, despite being less accurate.
                sharedAppData.saveCaptureData(captureData)
                addCaptureDataToCurrentDataset(
                    captureImageData: captureData.imageData, captureMeshData: captureData.meshData,
                    location: captureLocation, heading: captureHeading
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
        location: CLLocationCoordinate2D?,
        heading: CLLocationDirection?
    ) {
        Task {
            do {
                try sharedAppData.currentDatasetEncoder?.addCaptureData(
                    captureImageData: captureImageData,
                    captureMeshData: captureMeshData,
                    location: location,
                    heading: heading
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
            shouldUpdateMap = distance > Constants.WorkspaceConstants.fetchUpdateRadiusThresholdInMeters
        }
        if !shouldUpdateMap {
            return
        }
        Task {
            do {
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
                    radius: Constants.WorkspaceConstants.fetchRadiusInMeters,
                    accessToken: accessToken,
                    environment: userStateViewModel.selectedEnvironment
                )
                sharedAppData.currentMappingData.update(
                    osmMapDataResponse: mapData,
                    accessibilityFeatureClasses: selectedClasses
                )
            } catch {
                mappingDataStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
            }
        }
    }
    
    /// Set text for 2 seconds, and then fall back to placeholder
    private func setHintText(_ text: String) {
        cameraHintText = text
        Task {
            try await Task.sleep(for: .seconds(2))
            cameraHintText = cameraHintDefaultText
        }
    }
}
