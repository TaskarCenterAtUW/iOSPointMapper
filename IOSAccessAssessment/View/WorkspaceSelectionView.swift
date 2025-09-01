//
//  WorkspaceSelectionView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/25/25.
//

import SwiftUI

enum WorkspaceSelectionViewConstants {
    enum Texts {
        static let workspaceListViewTitle: String = "Workspace List View"
        static let noWorkspacesAvailable: String = "No workspaces available."
        
        static let selectWorkspacePrompt: String = "Select a workspace from the list below:"
        static let primaryWorkspaces: String = "Primary Workspaces"
        static let allWorkspaces: String = "All Workspaces"
    }
}

struct WorkspaceSelectionView: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @State var workspaces: [Workspace] = []
    @State var primaryWorkspaces: [Workspace] = []
    
    var body: some View {
        VStack {
            Text(WorkspaceSelectionViewConstants.Texts.workspaceListViewTitle)
                .font(.headline)
            
            VStack {
                Text(WorkspaceSelectionViewConstants.Texts.selectWorkspacePrompt)
                    .padding(.bottom, 10)
                
                if primaryWorkspaces.count > 0 {
                    Text(WorkspaceSelectionViewConstants.Texts.primaryWorkspaces)
                        .font(.subheadline)
                        .padding(.bottom, 5)
                    
                    ViewThatFits(in: .vertical) {
                        WorkspaceListView(workspaces: primaryWorkspaces, workspaceViewModel: workspaceViewModel)
                        ScrollView(.vertical) {
                            WorkspaceListView(workspaces: primaryWorkspaces, workspaceViewModel: workspaceViewModel)
                        }
                    }
                }
                
                if workspaces.count > 0 {
                    Text(WorkspaceSelectionViewConstants.Texts.allWorkspaces)
                        .font(.subheadline)
                        .padding(.bottom, 5)
                    
                    ScrollView(.vertical) {
                        WorkspaceListView(workspaces: workspaces, workspaceViewModel: workspaceViewModel)
                    }
                } else {
                    Text(WorkspaceSelectionViewConstants.Texts.noWorkspacesAvailable)
                        .foregroundColor(.gray)
                        .italic()
                }
            }
        }
        .padding()
        .task {
            await loadWorkspaces()
        }
//        .environment(\.colorScheme, .dark)
    }
    
    func loadWorkspaces() async {
        do {
            let workspaces = try await WorkspaceService.shared.fetchWorkspaces(location: nil, radius: 2000)
            let primaryWorkspaces = workspaces.filter { workspace in
                return Constants.WorkspaceConstants.primaryWorkspaceIds.contains("\(workspace.id)")
            }
            self.workspaces = workspaces
            self.primaryWorkspaces = primaryWorkspaces
        } catch {
            print("Error loading workspaces: \(error)")
        }
    }
}

struct WorkspaceListView: View {
    var workspaces: [Workspace]
    var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        VStack {
            ForEach(workspaces, id: \.id) { workspace in
                Button {
                    // Handle workspace selection
                    workspaceViewModel.workspaceSelected(id: "\(workspace.id)")
                } label: {
                    Text(workspace.title)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
        }
    }
}
