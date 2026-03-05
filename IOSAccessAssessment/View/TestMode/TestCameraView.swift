//
//  TestView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import SwiftUI

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
    
    var body: some View {
        VStack {
            Text("Test Mapping for workspace: \(workspaceId), changeset: \(changesetId)")
        }
        .navigationBarTitle("Test Mapping", displayMode: .inline)
        .onAppear {
            initializeCurrentDatasetReader()
            loadData()
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
        } catch {
            print("Error loading data: \(error)")
        }
    }
    
    private func cameraOutputImageCallback(_ captureImageData: (any CaptureImageDataProtocol)) {
        Task {
            await sharedAppData.appendCaptureDataToQueue(captureImageData)
        }
    }
}
