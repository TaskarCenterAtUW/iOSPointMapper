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
    let selectedAttributesByClass: [AccessibilityFeatureClass: Set<AccessibilityFeatureAttribute>]
    
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var datasetLister: DatasetLister = DatasetLister()
    @State private var selectedEnvironment: APIEnvironment?
    
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
        .navigationDestination(item: $selectedEnvironment) { environmentDir in
            TestWorkspaceListView(
                selectedClasses: selectedClasses, selectedAttributesByClass: selectedAttributesByClass,
                datasetLister: datasetLister
            )
        }
    }
    
    func selectEnvironment(environmentDir: EnvironmentDirectory) {
        do {
            try datasetLister.selectEnvironment(environmentDirectory: environmentDir)
            self.selectedEnvironment = environmentDir.apiEnvironment
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
    let selectedAttributesByClass: [AccessibilityFeatureClass: Set<AccessibilityFeatureAttribute>]
    @ObservedObject var datasetLister: DatasetLister
    
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedWorkspace: WorkspaceDirectory?
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
                        Button {
                            selectWorkspace(workspaceDir: workspaceDir)
                        } label: {
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
        .navigationDestination(item: $selectedWorkspace) { workspaceDir in
            TestChangesetListView(
                selectedClasses: selectedClasses, selectedAttributesByClass: selectedAttributesByClass,
                datasetLister: datasetLister
            )
        }
    }
    
    func selectWorkspace(workspaceDir: WorkspaceDirectory) {
        do {
            try datasetLister.selectWorkspace(workspaceDirectory: workspaceDir)
            self.selectedWorkspace = workspaceDir
        } catch {
            print("Error selecting workspace: \(error)")
        }
    }
}

/**
 TestChangesetListView displays the possible changesets of a workspace whose inputs can be used to simulate the mapping.
 */
struct TestChangesetListView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    let selectedAttributesByClass: [AccessibilityFeatureClass: Set<AccessibilityFeatureAttribute>]
    @ObservedObject var datasetLister: DatasetLister
    
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedChangeset: ChangesetDirectory?
    
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
                        Button {
                            selectChangeset(changesetDir: changesetDir)
                        } label: {
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
        .navigationDestination(item: $selectedChangeset) { changesetDir in
            changesetDestination(changesetDir: changesetDir)
        }
    }
    
    func selectChangeset(changesetDir: ChangesetDirectory) {
        self.selectedChangeset = changesetDir
        datasetLister.selectChangeset(changesetDirectory: changesetDir)
    }
    
    @ViewBuilder
    private func changesetDestination(changesetDir: ChangesetDirectory) -> some View {
        if let selectedEnvironment = datasetLister.selectedEnvironment,
           let selectedWorkspace = datasetLister.selectedWorkspace {
            TestCameraView(
                selectedClasses: selectedClasses, selectedAttributesByClass: selectedAttributesByClass,
                selectedEnvironment: selectedEnvironment.apiEnvironment,
                workspaceId: selectedWorkspace.workspaceId, changesetId: changesetDir.changesetId
            )
        } else {
            Text("Missing environment or workspace selection.")
        }
    }
}
