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
            Text("Test Mapping for workspace: \(workspaceId), changeset: \(changesetId)")
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
