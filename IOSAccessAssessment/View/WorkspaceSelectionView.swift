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
        
        /// Workspace Fetch Status Alert
        static let workspaceFetchStatusAlertTitleKey: String = "Workspace Load Error"
        static let workspaceFetchStatusAlertDismissButtonKey: String = "Dismiss"
        static let workspaceFetchStatusAlertRetryButtonKey: String = "Retry"
        static let workspaceFetchStatusAlertLogoutButtonKey: String = "Log out"
        static let workspaceFetchStatusAlertMessageKey: String = "There was an error loading workspaces:\n%@\nPlease try again.\nIf the problem persists, please relogin.\n"
        
        /// WorkspaceInfoTip
        static let workspaceInfoTipTitle: String = "Workspace"
        static let workspaceInfoTipMessage: String = "A working space where one can edit and contribute to OpenSidewalk (OSW) data"
        static let workspaceInfoTipLearnMoreButtonTitle: String = "Learn More"
        
        /// WorkspaceSelectionLearnMoreSheetView
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
        static let workspaceInfoTipLearnMoreActionId: String = "workspaces-learn-more"
    }
}

enum WorkspaceSelectionViewError: Error, LocalizedError {
    case failedToLoadWorkspaces
    case authenticationError

    var errorDescription: String? {
        switch self {
        case .failedToLoadWorkspaces:
            return "Failed to load workspaces. Please try again."
        case .authenticationError:
            return "Authentication error. Please log in again."
        }
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

class WorkspaceFetchStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    
    func update(isFailed: Bool, errorMessage: String) {
        self.isFailed = isFailed
        self.errorMessage = errorMessage
    }
}

struct WorkspaceSelectionView: View {
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @State var workspaces: [Workspace] = []
    @State var primaryWorkspaces: [Workspace] = []
    
    @StateObject private var workspaceFetchStatusViewModel = WorkspaceFetchStatusViewModel()
    @EnvironmentObject var userState: UserStateViewModel
    
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
        .alert(WorkspaceSelectionViewConstants.Texts.workspaceFetchStatusAlertTitleKey, isPresented: $workspaceFetchStatusViewModel.isFailed, actions: {
            Button(WorkspaceSelectionViewConstants.Texts.workspaceFetchStatusAlertDismissButtonKey) {
                workspaceFetchStatusViewModel.update(isFailed: false, errorMessage: "")
            }
            Button(WorkspaceSelectionViewConstants.Texts.workspaceFetchStatusAlertRetryButtonKey, role: .cancel) {
                workspaceFetchStatusViewModel.update(isFailed: false, errorMessage: "")
                Task {
                    await loadWorkspaces()
                }
            }
            Button(WorkspaceSelectionViewConstants.Texts.workspaceFetchStatusAlertLogoutButtonKey, role: .destructive) {
                workspaceFetchStatusViewModel.update(isFailed: false, errorMessage: "")
                userState.logout()
            }
        }, message: {
            Text(String(
                format: NSLocalizedString(WorkspaceSelectionViewConstants.Texts.workspaceFetchStatusAlertMessageKey, comment: ""),
                workspaceFetchStatusViewModel.errorMessage
            ))
        })
//        .environment(\.colorScheme, .dark)
    }
    
    func loadWorkspaces() async {
        do {
            guard let accessToken = userStateViewModel.getAccessToken() else {
                throw WorkspaceSelectionViewError.authenticationError
            }
            var workspaces = try await WorkspaceService.shared.fetchWorkspaces(
                location: nil, radius: 2000,
                accessToken: accessToken
            )
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
            self.workspaces = []
            self.primaryWorkspaces = []
            workspaceFetchStatusViewModel.update(isFailed: true, errorMessage: error.localizedDescription)
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
                .font(.headline)
            Text(WorkspaceSelectionViewConstants.Texts.workspaceSelectionLearnMoreSheetMessage)
                .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}
