//
//  TesterListView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 3/3/26.
//

import SwiftUI
import TipKit

enum TestListViewError: Error, LocalizedError {
    case workspaceIdUnavailable
    
    var errorDescription: String? {
        switch self {
        case .workspaceIdUnavailable:
            return "Workspace ID is unavailable. Please ensure you are in a valid workspace."
        }
    }
}

/**
 TestListView displays the possible changesets whose inputs can be used to simulate the mapping.
 */
struct TestListView: View {
    let selectedClasses: [AccessibilityFeatureClass]
    
    @EnvironmentObject var sharedAppData: SharedAppData
    @EnvironmentObject var sharedAppContext: SharedAppContext
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @Environment(\.dismiss) var dismiss
    
    var datasetLister: DatasetLister = DatasetLister()
    
    var body: some View {
        Text("Test List View")
        .onAppear {
            do {
                guard let workspaceId = workspaceViewModel.workspaceId else {
                    throw TestListViewError.workspaceIdUnavailable
                }
                try datasetLister.configure(workspaceId: workspaceId)
            } catch {
                print("Error fetching datasets: \(error)")
            }
        }
    }
}
