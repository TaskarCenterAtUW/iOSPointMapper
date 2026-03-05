//
//  TestView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import SwiftUI

/**
 TestCameraView uses the data saved in the changeset directory, to simulate mapping
 */
struct TestCameraView: View {
    let workspaceId: String
    let changesetId: String
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @EnvironmentObject var sharedAppContext: SharedAppContext
    
    @State private var currentIndex: Int = 0
    
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
}
