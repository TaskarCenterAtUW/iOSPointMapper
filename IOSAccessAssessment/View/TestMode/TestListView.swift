//
//  TesterListView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import SwiftUI
import TipKit
import PointNMapShared

enum TestListViewError: Error, LocalizedError {
    case workspacesUnavailable
    case workspaceIdUnavailable
    
    var errorDescription: String? {
        switch self {
        case .workspacesUnavailable:
            return "Workspaces are unavailable. Please ensure you have access to the workspace datasets."
        case .workspaceIdUnavailable:
            return "Workspace ID is unavailable. Please ensure you are in a valid workspace."
        }
    }
}

struct TestEnvironmentListView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var datasetLister: DatasetLister = DatasetLister()
    @State private var selectedEnvironmentDir: EnvironmentDirectory?
    
    var body: some View {
        VStack {
            HStack {
                Text("Please select an environment dataset:")
                    .font(.subheadline)
                    .padding(.bottom, 5)
            }
            
            if datasetLister.environmentDirectories.count > 0 {
                List {
                    ForEach(datasetLister.environmentDirectories, id: \.self) { environmentDir in
                        Button {
                            selectEnvironment(environmentDir: environmentDir)
                        } label: {
                            Text(environmentDir.url.lastPathComponent)
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                }
            } else {
                Text("No environment datasets found.")
                Spacer()
            }
        }
        .navigationBarTitle("Test: Environment Selection", displayMode: .inline)
        .onAppear {
            do {
                try datasetLister.configure()
            } catch {
                print("Error fetching environment datasets: \(error)")
            }
        }
    }
    
    func selectEnvironment(environmentDir: EnvironmentDirectory) {
        do {
            self.selectedEnvironmentDir = environmentDir
            try datasetLister.selectEnvironment(environmentDirectory: environmentDir)
        } catch {
            print("Error selecting environment: \(error)")
        }
    }
}

/**
 TestWorkspaceListView displays the possible workspace datasets whose inputs can be used to simulate the mapping.
 */
struct TestWorkspaceListView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    @ObservedObject var datasetLister: DatasetLister
    
    @Environment(\.dismiss) var dismiss
    
//    let datasetLister: DatasetLister = DatasetLister()
    
    var body: some View {
        VStack {
            HStack {
                Text("Please select a workspace dataset:")
                    .font(.subheadline)
                    .padding(.bottom, 5)
            }
            
            if datasetLister.workspaceDirectories.count > 0 {
                List {
                    ForEach(datasetLister.workspaceDirectories, id: \.self) { workspaceDir in
                        NavigationLink(
                            destination: TestChangesetListView(
                                selectedClasses: selectedClasses, datasetLister: datasetLister
                            )
                        ) {
                            Text(workspaceDir.url.lastPathComponent)
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                }
            } else {
                Text("No workspace datasets found.")
                Spacer()
            }
        }
        .navigationBarTitle("Test: Workspace Selection", displayMode: .inline)
        .onAppear {
            do {
//                try datasetLister.configure()
                let environmentRawValue = environmentDir.lastPathComponent
                try datasetLister.selectEnvironment(environmentRawValue: environmentRawValue)
            } catch {
                print("Error fetching workspace datasets: \(error)")
            }
        }
    }
}

/**
 TestChangesetListView displays the possible changesets of a workspace whose inputs can be used to simulate the mapping.
 */
struct TestChangesetListView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    @ObservedObject var datasetLister: DatasetLister
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Text("Please select a changeset dataset:")
                    .font(.subheadline)
                    .padding(.bottom, 5)
            }
            
            if datasetLister.changesetDirectories.count > 0 {
                List {
                    ForEach(datasetLister.changesetDirectories, id: \.self) { changesetDir in
                        NavigationLink(destination: changesetDestination(changesetDir: changesetDir)) {
                            Text(changesetDir.url.lastPathComponent)
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                    }
                }
            } else {
                Text("No changeset datasets found for the selected workspace.")
                Spacer()
            }
        }
        .navigationBarTitle("Test: Changeset Selection", displayMode: .inline)
        .onAppear {
            do {
                let workspaceId = workspaceDir.lastPathComponent
                try datasetLister.selectWorkspace(workspaceId: workspaceId)
            } catch {
                print("Error selecting workspace: \(error)")
            }
        }
    }
    
    @ViewBuilder
    private func changesetDestination(workspaceDir: URL, changesetDir: URL) -> some View {
//        let selectedEnvironment = APIEnvironment(rawValue: environmentDir.lastPathComponent)
//        let workspaceId: String = workspaceDir.lastPathComponent
//        let changesetId: String = changesetDir.lastPathComponent
        let selectedEnvironment = datasetLister.apiEnvironment
        TestCameraView(
            selectedClasses: selectedClasses, selectedEnvironment: selectedEnvironment,
            workspaceId: workspaceId, changesetId: changesetId
        )
    }
}
