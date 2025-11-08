//
//  SetupView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
import TipKit

enum SetupViewConstants {
    enum Texts {
        static let setupViewTitle = "Setup"
        static let uploadChangesetTitle = "Upload Changeset"
        static let selectClassesText = "Select Classes to Identify"
        
        static let changesetOpeningErrorTitle = "Changeset failed to open. Please retry."
        static let changesetOpeningRetryText = "Retry"
        static let changesetOpeningRetryMessageText = "Failed to open changeset."
        static let workspaceIdMissingMessageText = "Workspace ID is missing."
        static let changesetClosingErrorTitle = "Changeset failed to close. Please retry."
        static let changesetClosingRetryText = "Retry"
        static let changesetClosingRetryMessageText = "Failed to close changeset."
        
        static let confirmationDialogTitle = "Are you sure you want to log out?"
        static let confirmationDialogConfirmText = "Log out"
        static let confirmationDialogCancelText = "Cancel"
        
        static let nextButton = "Next"
        
        // ChangesetInfoTip
        static let changesetInfoTipTitle = "Upload Changeset"
        static let changesetInfoTipMessage = "Upload your collected data as a changeset to the workspace."
        static let changesetInfoTipLearnMoreButtonTitle = "Learn More"
        
        // ChangesetInfoLearnMoreSheetView
        static let changesetInfoLearnMoreSheetTitle = "About Changesets"
        static let changesetInfoLearnMoreSheetMessage = """
        A changeset is a collection of changes made to the workspace. It allows you to group related modifications together for easier management and tracking.
        
        Click the Upload Changeset button to upload your collected data as a changeset to the workspace.
        """
        
        // SelectClassesInfoTip
        static let selectClassesInfoTipTitle = "Select Classes"
        static let selectClassesInfoTipMessage = "Please select the type of environment objects that you want the application to map during the mapping session."
        static let selectClassesInfoTipLearnMoreButtonTitle = "Learn More"
        
        // SelectClassesInfoLearnMoreSheetView
        static let selectClassesInfoLearnMoreSheetTitle = "About Class Selection"
        static let selectClassesInfoLearnMoreSheetMessage = """
        Each class represents a specific type of object or feature in the environment, such as sidewalks, buildings, traffic signs, etc.
        
        Selecting specific classes helps the application focus on mapping the objects that are most relevant to your needs. 
        
        Please select the classes you want to identify during the mapping session from the list provided.
        """
    }
    
    enum Images {
        static let profileIcon = "person.crop.circle"
        static let logoutIcon = "rectangle.portrait.and.arrow.right"
        static let uploadIcon = "arrow.up"
        
        // ChangesetInfoTip
        static let infoIcon = "info.circle"
    }
    
    enum Colors {
        static let selectedClass = Color(red: 187/255, green: 134/255, blue: 252/255)
        static let unselectedClass = Color.primary
    }
    
    enum Constraints {
        static let logoutIconSize: CGFloat = 20
    }
    
    enum Identifiers {
        static let changesetInfoTipLearnMoreActionId: String = "changeset-learn-more"
        static let selectClassesInfoTipLearnMoreActionId: String = "select-classes-learn-more"
    }
}

struct ChangesetInfoTip: Tip {
    
    var title: Text {
        Text(SetupViewConstants.Texts.changesetInfoTipTitle)
    }
    var message: Text? {
        Text(SetupViewConstants.Texts.changesetInfoTipMessage)
    }
    var image: Image? {
        Image(systemName: SetupViewConstants.Images.infoIcon)
            .resizable()
//            .frame(width: 30, height: 30)
    }
    var actions: [Action] {
        // Define a learn more button.
        Action(
            id: SetupViewConstants.Identifiers.changesetInfoTipLearnMoreActionId,
            title: SetupViewConstants.Texts.changesetInfoTipLearnMoreButtonTitle
        )
    }
}

struct SelectClassesInfoTip: Tip {
    
    var title: Text {
        Text(SetupViewConstants.Texts.selectClassesInfoTipTitle)
    }
    var message: Text? {
        Text(SetupViewConstants.Texts.selectClassesInfoTipMessage)
    }
    var image: Image? {
        Image(systemName: SetupViewConstants.Images.infoIcon)
            .resizable()
    }
    var actions: [Action] {
        // Define a learn more button.
        Action(
            id: SetupViewConstants.Identifiers.selectClassesInfoTipLearnMoreActionId,
            title: SetupViewConstants.Texts.selectClassesInfoTipLearnMoreButtonTitle
        )
    }
}

class ChangeSetOpenViewModel: ObservableObject {
    @Published var isChangesetOpened: Bool = false
    @Published var showOpeningRetryAlert: Bool = false
    @Published var openRetryMessage: String = ""
    
    func update(isChangesetOpened: Bool, showOpeningRetryAlert: Bool, openRetryMessage: String) {
        objectWillChange.send()
        
        self.isChangesetOpened = isChangesetOpened
        self.showOpeningRetryAlert = showOpeningRetryAlert
        self.openRetryMessage = openRetryMessage
    }
}

class ChangeSetCloseViewModel: ObservableObject {
//    @Published var isChangesetClosed = false
    @Published var showClosingRetryAlert = false
    @Published var closeRetryMessage = ""
    
    func update(showClosingRetryAlert: Bool, closeRetryMessage: String) {
        objectWillChange.send()
        
        self.showClosingRetryAlert = showClosingRetryAlert
        self.closeRetryMessage = closeRetryMessage
    }
}

struct SetupView: View {
    @State private var selection = Set<Int>()
    private var isSelectionEmpty: Bool {
        return (self.selection.count == 0)
    }
    
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
//    @EnvironmentObject var userState: UserStateViewModel
//    @State private var showLogoutConfirmation = false
    
    @StateObject private var changesetOpenViewModel = ChangeSetOpenViewModel()
    @StateObject private var changeSetCloseViewModel = ChangeSetCloseViewModel()
    
    @StateObject private var sharedImageData: SharedImageData = SharedImageData()
    @StateObject private var segmentationPipeline: SegmentationARPipeline = SegmentationARPipeline()
    @StateObject private var segmentationMeshPipeline: SegmentationMeshPipeline = SegmentationMeshPipeline()
    @StateObject private var depthModel: DepthModel = DepthModel()
    
    var changesetInfoTip = ChangesetInfoTip()
    @State private var showChangesetLearnMoreSheet = false
    var selectClassesInfoTip = SelectClassesInfoTip()
    @State private var showSelectClassesLearnMoreSheet = false
    
    var body: some View {
        return NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    HStack {
                        Text(SetupViewConstants.Texts.uploadChangesetTitle)
                            .font(.headline)
                        Button(action: {
                            showChangesetLearnMoreSheet = true
                        }) {
                            Image(systemName: WorkspaceSelectionViewConstants.Images.infoIcon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Button (action: {
                        print("Uploading changeset...")
                        closeChangeset()
                    }) {
                        Image(systemName: SetupViewConstants.Images.uploadIcon)
                            .resizable()
                            .frame(width: 20, height: 20)
//                            .foregroundColor(.white)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!sharedImageData.isUploadReady)
                }
                .padding(.bottom, 10)
                TipView(changesetInfoTip, arrowEdge: .top) { action in
                    if action.id == SetupViewConstants.Identifiers.changesetInfoTipLearnMoreActionId {
                        showChangesetLearnMoreSheet = true
                    }
                }
                
                Divider()
                
                HStack {
                    Text(SetupViewConstants.Texts.selectClassesText)
                        .font(.headline)
    //                    .foregroundColor(.gray)
                    Button(action: {
                        showSelectClassesLearnMoreSheet = true
                    }) {
                        Image(systemName: WorkspaceSelectionViewConstants.Images.infoIcon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                    Spacer()
                }
                .padding(.bottom, 10)
                TipView(selectClassesInfoTip, arrowEdge: .top) { action in
                    if action.id == SetupViewConstants.Identifiers.selectClassesInfoTipLearnMoreActionId {
                        showSelectClassesLearnMoreSheet = true
                    }
                }
                
                List {
                    ForEach(0..<Constants.SelectedSegmentationConfig.classNames.count, id: \.self) { index in
                        Button(action: {
                            if self.selection.contains(index) {
                                self.selection.remove(index)
                            } else {
                                self.selection.insert(index)
                            }
                        }) {
                            Text(Constants.SelectedSegmentationConfig.classNames[index])
                                .foregroundColor(
                                    self.selection.contains(index)
                                    ? SetupViewConstants.Colors.selectedClass
                                    : SetupViewConstants.Colors.unselectedClass
                                )
                        }
                    }
                }
            }
            .padding()
            .navigationBarTitle(SetupViewConstants.Texts.setupViewTitle, displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading:
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: SetupViewConstants.Images.profileIcon)
                            .resizable()
                            .frame(
                                width: SetupViewConstants.Constraints.logoutIconSize,
                                height: SetupViewConstants.Constraints.logoutIconSize
                            )
                            .bold()
                    }
                ,
                trailing:
                    NavigationLink(
                        destination: ARCaptureView(selection: Array(selection.sorted()))
                    ) {
                        Text(SetupViewConstants.Texts.nextButton)
                            .foregroundStyle(isSelectionEmpty ? Color.gray : Color.primary)
                            .font(.headline)
                    }
                    .disabled(isSelectionEmpty)
            )
            // Alert for logout confirmation
//            .alert(
//                SetupViewConstants.Texts.confirmationDialogTitle,
//                isPresented: $showLogoutConfirmation
//            ) {
//                Button(SetupViewConstants.Texts.confirmationDialogConfirmText, role: .destructive) {
//                    userState.logout()
//                }
//                Button(SetupViewConstants.Texts.confirmationDialogCancelText, role: .cancel) { }
//            }
            // Alert for changeset opening error
            .alert(SetupViewConstants.Texts.changesetOpeningErrorTitle, isPresented: $changesetOpenViewModel.showOpeningRetryAlert) {
                Button(SetupViewConstants.Texts.changesetOpeningRetryText) {
                    changesetOpenViewModel.update(isChangesetOpened: false, showOpeningRetryAlert: false, openRetryMessage: "")
                    
                    openChangeset()
                }
            } message: {
                Text(changesetOpenViewModel.openRetryMessage)
            }
            // Alert for changeset closing error
            .alert(SetupViewConstants.Texts.changesetClosingErrorTitle, isPresented: $changeSetCloseViewModel.showClosingRetryAlert) {
                Button(SetupViewConstants.Texts.changesetClosingRetryText) {
                    changeSetCloseViewModel.update(showClosingRetryAlert: false, closeRetryMessage: "")
                    
                    closeChangeset()
                }
            } message: {
                Text(changeSetCloseViewModel.closeRetryMessage)
            }
            .onAppear {
                if !changesetOpenViewModel.isChangesetOpened {
                    openChangeset()
                }
            }
            .sheet(isPresented: $showChangesetLearnMoreSheet) {
                ChangesetLearnMoreSheetView()
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSelectClassesLearnMoreSheet) {
                SelectClassesLearnMoreSheetView()
                    .presentationDetents([.medium, .large])
            }
        }
        .environmentObject(self.sharedImageData)
        .environmentObject(self.segmentationPipeline)
        .environmentObject(self.segmentationMeshPipeline)
        .environmentObject(self.depthModel)
//        .environment(\.colorScheme, .dark)
    }
    
    private func openChangeset() {
        guard let workspaceId = workspaceViewModel.workspaceId else {
            DispatchQueue.main.async {
                changesetOpenViewModel.update(
                    isChangesetOpened: false, showOpeningRetryAlert: true,
                    openRetryMessage: "\(SetupViewConstants.Texts.changesetOpeningRetryMessageText) \nError: \(SetupViewConstants.Texts.workspaceIdMissingMessageText)")
            }
            return
        }
        ChangesetService.shared.openChangeset(workspaceId: workspaceId) { result in
            switch result {
            case .success(let changesetId):
                print("Opened changeset with ID: \(changesetId)")
                DispatchQueue.main.async {
                    changesetOpenViewModel.isChangesetOpened = true
                    
                    // Open a dataset encoder for the changeset
                    sharedImageData.currentDatasetEncoder = DatasetEncoder(workspaceId: workspaceId, changesetId: changesetId)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    changesetOpenViewModel.update(
                        isChangesetOpened: false, showOpeningRetryAlert: true,
                        openRetryMessage: "\(SetupViewConstants.Texts.changesetOpeningRetryMessageText) \nError: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func closeChangeset() {
        ChangesetService.shared.closeChangeset { result in
            switch result {
            case .success:
                print("Changeset closed successfully.")
                DispatchQueue.main.async {
                    sharedImageData.refreshData()
                    sharedImageData.currentDatasetEncoder?.save()
                    
                    openChangeset()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    changeSetCloseViewModel.update(
                        showClosingRetryAlert: true,
                        closeRetryMessage: "\(SetupViewConstants.Texts.changesetClosingRetryMessageText) \nError: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct ChangesetLearnMoreSheetView: View {
    @Environment(\.dismiss)
    var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
//            Image(systemName: "number")
//                .resizable()
//                .scaledToFit()
//                .frame(width: 160)
//                .foregroundColor(.accentColor)
            Text(SetupViewConstants.Texts.changesetInfoLearnMoreSheetTitle)
                .font(.title)
            Text(SetupViewConstants.Texts.changesetInfoLearnMoreSheetMessage)
            .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}

struct SelectClassesLearnMoreSheetView: View {
    @Environment(\.dismiss)
    var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            //            Image(systemName: "number")
            //                .resizable()
            //                .scaledToFit()
            //                .frame(width: 160)
            //                .foregroundColor(.accentColor)
            Text(SetupViewConstants.Texts.selectClassesInfoLearnMoreSheetTitle)
                .font(.title)
            Text(SetupViewConstants.Texts.selectClassesInfoLearnMoreSheetMessage)
                .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}
