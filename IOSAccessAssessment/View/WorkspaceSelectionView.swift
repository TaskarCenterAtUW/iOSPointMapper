//
//  WorkspaceSelectionView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/25/25.
//

import SwiftUI
import TipKit

enum WorkspaceSelectionViewConstants {
    enum Texts {
        static let workspaceListViewTitle: String = "Workspaces"
        static let noWorkspacesAvailable: String = "No workspaces available."
        
        static let selectWorkspacePrompt: String = "Select a workspace from the list below"
        static let primaryWorkspaces: String = "Primary Workspaces"
        static let allWorkspaces: String = "All Workspaces"
        
        // WorkspaceInfoTip
        static let workspaceInfoTipTitle: String = "Workspace"
        static let workspaceInfoTipMessage: String = "A working space where one can edit and contribute to OpenSidewalk (OSW) data"
        static let workspaceInfoTipLearnMoreButtonTitle: String = "Learn More"
        
        // WorkspaceSelectionLearnMoreSheetView
        static let workspaceSelectionLearnMoreSheetTitle: String = "Workspace"
        static let workspaceSelectionLearnMoreSheetMessage: String = """
            A working space where one can edit and contribute to OpenSidewalk (OSW) data such as sidewalks, intersections, curbs etc.
            """
    }
    
    enum Images {
        static let refreshIcon: String = "arrow.clockwise.circle"
        
        // WorkspaceInfoTip
        static let infoIcon: String = "info.circle"
    }
    
    enum Constraints {
        static let refreshIconSize: CGFloat = 20
        static let profileIconSize: CGFloat = 20
    }
    
    enum Identifiers {
        static let workspaceInfoTipLearnMoreActionId: String = "learn-more"
    }
}

struct WorkspaceInfoTip: Tip {
    
    var title: Text {
        Text(WorkspaceSelectionViewConstants.Texts.workspaceInfoTipTitle)
    }
    var message: Text? {
        Text(WorkspaceSelectionViewConstants.Texts.workspaceInfoTipMessage)
    }
    var image: Image? {
        Image(systemName: WorkspaceSelectionViewConstants.Images.infoIcon)
            .resizable()
//            .frame(width: 30, height: 30)
    }
    var actions: [Action] {
        // Define a learn more button.
        Action(
            id: WorkspaceSelectionViewConstants.Identifiers.workspaceInfoTipLearnMoreActionId,
            title: WorkspaceSelectionViewConstants.Texts.workspaceInfoTipLearnMoreButtonTitle
        )
    }
}

struct WorkspaceSelectionView: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @State var workspaces: [Workspace] = []
    @State var primaryWorkspaces: [Workspace] = []
    
    var infoTip = WorkspaceInfoTip()
    @State private var showLearnMoreSheet = false
    
    var body: some View {
        return NavigationStack {
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        showLearnMoreSheet = true
                    }) {
                        Image(systemName: WorkspaceSelectionViewConstants.Images.infoIcon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    .padding(.trailing, 5)
                }
                .padding(.vertical, 5)
                .overlay(
                    Text(WorkspaceSelectionViewConstants.Texts.selectWorkspacePrompt)
                        .padding(.horizontal, 10)
                        .fixedSize(horizontal: false, vertical: true)
                )
                TipView(infoTip, arrowEdge: .top) { action in
                    if action.id == WorkspaceSelectionViewConstants.Identifiers.workspaceInfoTipLearnMoreActionId {
                        showLearnMoreSheet = true
                    }
                }
                
                if primaryWorkspaces.count > 0 {
                    Text(WorkspaceSelectionViewConstants.Texts.primaryWorkspaces)
                        .font(.headline)
                        .padding(.top, 5)
                    
                    ViewThatFits(in: .vertical) {
                        WorkspaceListView(workspaces: primaryWorkspaces, workspaceViewModel: workspaceViewModel)
                        ScrollView(.vertical) {
                            WorkspaceListView(workspaces: primaryWorkspaces, workspaceViewModel: workspaceViewModel)
                        }
                    }
                }
                
                HStack {
                    Text(WorkspaceSelectionViewConstants.Texts.allWorkspaces)
                        .font(.headline)
                    Button(action: {
                        Task {
                            await loadWorkspaces()
                        }
                    }) {
                        Image(systemName: WorkspaceSelectionViewConstants.Images.refreshIcon)
                            .resizable()
                            .frame(
                                width: WorkspaceSelectionViewConstants.Constraints.refreshIconSize,
                                height: WorkspaceSelectionViewConstants.Constraints.refreshIconSize
                            )
                            .bold()
                    }
                }
                .padding(.top, 10)
                
                if workspaces.count > 0 {
                    ScrollView(.vertical) {
                        WorkspaceListView(workspaces: workspaces, workspaceViewModel: workspaceViewModel)
                    }
                    .refreshable {
                        Task {
                            await loadWorkspaces()
                        }
                    }
                } else {
                    Text(WorkspaceSelectionViewConstants.Texts.noWorkspacesAvailable)
                        .foregroundStyle(.gray)
                        .italic()
                        .padding(.top, 5)
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarTitle(WorkspaceSelectionViewConstants.Texts.workspaceListViewTitle, displayMode: .inline)
            .navigationBarItems(
                leading:
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: SetupViewConstants.Images.profileIcon)
                            .resizable()
                            .frame(
                                width: SetupViewConstants.Constraints.profileIconSize,
                                height: SetupViewConstants.Constraints.profileIconSize
                            )
                            .bold()
                    })
        }
        .padding()
        .task {
            await loadWorkspaces()
        }
        .sheet(isPresented: $showLearnMoreSheet) {
            WorkspaceSelectionLearnMoreSheetView()
                .presentationDetents([.medium, .large])
        }
//        .environment(\.colorScheme, .dark)
    }
    
    func loadWorkspaces() async {
        do {
            var workspaces = try await WorkspaceService.shared.fetchWorkspaces(location: nil, radius: 2000)
            // MARK: Eventually, we should ensure that even primary workspaces have externalAppAccess enabled
            let primaryWorkspaces = workspaces.filter { workspace in
                return Constants.WorkspaceConstants.primaryWorkspaceIds.contains("\(workspace.id)")
            }
            workspaces = workspaces.filter { workspace in
                return workspace.externalAppAccess == 1
            }
            self.workspaces = workspaces
            self.primaryWorkspaces = primaryWorkspaces
        } catch {
            print("Error loading workspaces: \(error.localizedDescription)")
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
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}

struct WorkspaceSelectionLearnMoreSheetView: View {
    @Environment(\.dismiss)
    var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
//            Image(systemName: "number")
//                .resizable()
//                .scaledToFit()
//                .frame(width: 160)
//                .foregroundStyle(.accentColor)
            Text(WorkspaceSelectionViewConstants.Texts.workspaceSelectionLearnMoreSheetTitle)
                .font(.title)
            Text(WorkspaceSelectionViewConstants.Texts.workspaceSelectionLearnMoreSheetMessage)
            .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}
