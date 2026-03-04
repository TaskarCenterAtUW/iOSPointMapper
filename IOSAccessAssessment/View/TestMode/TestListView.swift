//
//  TesterListView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import SwiftUI
import TipKit

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

/**
 TestWorkspaceListView displays the possible workspace datasets whose inputs can be used to simulate the mapping.
 */
struct TestWorkspaceListView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @EnvironmentObject var sharedAppContext: SharedAppContext
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @Environment(\.dismiss) var dismiss
    
    let datasetLister: DatasetLister = DatasetLister()
    
    var body: some View {
        VStack {
            if datasetLister.workspaceDirectories.count > 0 {
                List {
                    ForEach(datasetLister.workspaceDirectories, id: \.self) { workspaceDir in
                        Button(action: {
                            print("Selected workspace: \(workspaceDir)")
                        }) {
                            Text(workspaceDir.lastPathComponent)
                        }
                    }
                }
            } else {
                Text("No workspace datasets found.")
            }
        }
        .onAppear {
            do {
                try datasetLister.configure()
                print(datasetLister.workspaceDirectories)
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
    let workspaceId: String
    let datasetLister: DatasetLister
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @EnvironmentObject var sharedAppContext: SharedAppContext
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Text("Test Changeset List View")
        .onAppear {
            do {
                try datasetLister.selectWorkspace(workspaceId: workspaceId)
                print(datasetLister.changesetDirectories)
            } catch {
                print("Error selecting workspace: \(error)")
            }
        }
    }
}
