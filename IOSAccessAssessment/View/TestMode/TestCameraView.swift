//
//  TestView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import SwiftUI
import CoreLocation

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

class TestCameraManagerStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    
    func update(isFailed: Bool, errorMessage: String) {
        self.isFailed = isFailed
        self.errorMessage = errorMessage
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
    @StateObject private var managerConfigureStatusViewModel = TestCameraManagerStatusViewModel()
    
    @State private var currentIndex: Int = 0
    
    @State private var showAnnotationView = false
    
    // Latest dataset capture data
    @State private var datasetCaptureData: DatasetCaptureData?
    
    var body: some View {
        VStack {
            if manager.isConfigured {
                orientationStack {
                    HostedTestCameraViewContainer(arSessionCameraProcessingDelegate: manager)
                    VStack {
                        /// Text for hinting user with status
                        Text("Processing")
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
        .navigationBarTitle("Test Mapping", displayMode: .inline)
        .onAppear {
            initializeCurrentDatasetReader()
            loadData()
            do {
                try manager.configure(
                    selectedClasses: selectedClasses, segmentationPipeline: segmentationPipeline,
                    metalContext: sharedAppContext.metalContext,
                    cameraOutputImageCallback: cameraOutputImageCallback
                )
            } catch {
                print("Error configuring TestCameraManager: \(error)")
                
            }
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
    
    private func initializeCurrentDatasetReader() {
        do {
            sharedAppData.currentDatasetDecoder = try DatasetDecoder(workspaceId: workspaceId, changesetId: changesetId)
        } catch {
            print("Error initializing DatasetDecoder: \(error)")
        }
    }
    
    private func loadData() {
        do {
            guard let currentDatasetDecoder = sharedAppData.currentDatasetDecoder else {
                throw NSError(domain: "DatasetDecoderError", code: 1, userInfo: [NSLocalizedDescriptionKey: "DatasetDecoder not initialized"])
            }
            let datasetCaptureData = try currentDatasetDecoder.loadData(index: currentIndex)
            try manager.handleSessionFrameUpdate(datasetCaptureData: datasetCaptureData)
            self.datasetCaptureData = datasetCaptureData
        } catch {
            print("Error loading data: \(error)")
        }
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
            } catch {
                print("Error during camera capture: \(error)")
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
}
