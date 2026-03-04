//
//  TestView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import SwiftUI

/**
 TestMappingView uses the data saved in the changeset directory, to simulate mapping
 */
struct TestMappingView: View {
    @EnvironmentObject var sharedAppData: SharedAppData
    @EnvironmentObject var sharedAppContext: SharedAppContext
    
    let workspaceId: String
    let changesetId: String
    
    var body: some View {
        VStack {
            Text("Test Mapping for workspace: \(workspaceId), changeset: \(changesetId)")
        }
        .navigationBarTitle("Test Mapping", displayMode: .inline)
        .onAppear {
            initializeCurrentDatasetReader()
        }
    }
    
    private func initializeCurrentDatasetReader() {
        do {
            sharedAppData.currentDatasetDecoder = try DatasetDecoder(workspaceId: workspaceId, changesetId: changesetId)
        } catch {
            print("Error initializing DatasetDecoder: \(error)")
        }
    }
}
