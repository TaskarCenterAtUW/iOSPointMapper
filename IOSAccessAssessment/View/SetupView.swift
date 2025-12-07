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
        static let selectClassesText = "Select Feature Types to Map"
        
        /// Alerts
        static let changesetOpeningErrorTitle = "Changeset failed to open. Please retry."
        static let changesetOpeningRetryText = "Retry"
        static let changesetOpeningRetryMessageText = "Failed to open changeset."
        static let workspaceIdMissingMessageText = "Workspace ID is missing."
        static let changesetClosingErrorTitle = "Changeset failed to close. Please retry."
        static let changesetClosingRetryText = "Retry"
        static let changesetClosingRetryMessageText = "Failed to close changeset."
        static let modelInitializationErrorTitle = "Machine Learning Model initialization failed. Please retry."
        static let modelInitializationRetryText = "Retry"
        static let modelInitializationRetryMessageText = "Failed to initialize the machine learning model."
        static let sharedAppContextInitializationErrorTitle = "App Context configuration failed. Please retry."
        static let sharedAppContextInitializationRetryText = "Retry"
        static let sharedAppContextInitializationRetryMessageText = "Failed to configure the app context."
        
        static let confirmationDialogTitle = "Are you sure you want to log out?"
        static let confirmationDialogConfirmText = "Log out"
        static let confirmationDialogCancelText = "Cancel"
        
        static let nextButton = "Next"
        
        /// ChangesetInfoTip
        static let changesetInfoTipTitle = "Upload Changeset"
        static let changesetInfoTipMessage = "Upload your collected data as a changeset to the workspace."
        static let changesetInfoTipLearnMoreButtonTitle = "Learn More"
        
        /// ChangesetInfoLearnMoreSheetView
        static let changesetInfoLearnMoreSheetTitle = "About Changesets"
        static let changesetInfoLearnMoreSheetMessage = """
        A changeset is a collection of changes made to the workspace. It allows you to group related modifications together for easier management and tracking.
        
        Click the Upload Changeset button to upload your collected data as a changeset to the workspace.
        """
        
        /// SelectClassesInfoTip
        static let selectClassesInfoTipTitle = "Select Feature Types"
        static let selectClassesInfoTipMessage = "Please select the type of environment features that you want the application to map during the mapping session."
        static let selectClassesInfoTipLearnMoreButtonTitle = "Learn More"
        
        /// SelectClassesInfoLearnMoreSheetView
        static let selectClassesInfoLearnMoreSheetTitle = "About Feature Types"
        static let selectClassesInfoLearnMoreSheetMessage = """
        Each feature type represents a specific type of feature in the environment, such as sidewalks, buildings, traffic signs, etc.
        
        Selecting specific feature types helps the application focus on mapping the objects that are most relevant to your needs. 
        
        Please select the feature types you want to identify during the mapping session from the list provided.
        """
    }
    
    enum Images {
        static let profileIcon = "person.crop.circle"
        static let logoutIcon = "rectangle.portrait.and.arrow.right"
        static let uploadIcon = "arrow.up"
        
        /// InfoTip
        static let infoIcon = "info.circle"
    }
    
    enum Colors {
        static let selectedClass = Color(red: 187/255, green: 134/255, blue: 252/255)
        static let unselectedClass = Color.primary
    }
    
    enum Constraints {
        static let profileIconSize: CGFloat = 20
    }
    
    enum Identifiers {
        static let changesetInfoTipLearnMoreActionId: String = "changeset-learn-more"
        static let selectClassesInfoTipLearnMoreActionId: String = "select-classes-learn-more"
    }
}

enum SetupViewError: Error, LocalizedError {
    case noWorkspaceId
    case changesetOpenFailed
    case authenticationError
    
    var errorDescription: String? {
        switch self {
        case .noWorkspaceId:
            return "Workspace ID is missing."
        case .changesetOpenFailed:
            return "Failed to open changeset."
        case .authenticationError:
            return "Authentication error. Please log in again."
        }
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
    @Published var showRetryAlert: Bool = false
    @Published var retryMessage: String = ""
    
    func update(isChangesetOpened: Bool, showRetryAlert: Bool, retryMessage: String) {
        self.isChangesetOpened = isChangesetOpened
        self.showRetryAlert = showRetryAlert
        self.retryMessage = retryMessage
    }
}

class ChangeSetCloseViewModel: ObservableObject {
//    @Published var isChangesetClosed = false
    @Published var showRetryAlert = false
    @Published var retryMessage = ""
    
    func update(showRetryAlert: Bool, retryMessage: String) {
        self.showRetryAlert = showRetryAlert
        self.retryMessage = retryMessage
    }
}

class ModelInitializationViewModel: ObservableObject {
    @Published var areModelsInitialized: Bool = false
    @Published var showRetryAlert: Bool = false
    @Published var retryMessage: String = ""
    
    func update(areModelsInitialized: Bool, showRetryAlert: Bool, retryMessage: String) {
        self.areModelsInitialized = areModelsInitialized
        self.showRetryAlert = showRetryAlert
        self.retryMessage = retryMessage
    }
}

class SharedAppContextInitializationViewModel: ObservableObject {
    @Published var isContextConfigured: Bool = false
    @Published var showRetryAlert: Bool = false
    @Published var retryMessage: String = ""
    
    func update(isContextConfigured: Bool, showRetryAlert: Bool, retryMessage: String) {
        self.isContextConfigured = isContextConfigured
        self.showRetryAlert = showRetryAlert
        self.retryMessage = retryMessage
    }
}

struct SetupView: View {
    @State private var selectedClasses = Set<AccessibilityFeatureClass>()
    private var isSelectionEmpty: Bool {
        return (self.selectedClasses.count == 0)
    }
    
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    
    @StateObject private var sharedAppData: SharedAppData = SharedAppData()
    @StateObject private var sharedAppContext: SharedAppContext = SharedAppContext()
    @StateObject private var segmentationPipeline: SegmentationARPipeline = SegmentationARPipeline()
    
    @StateObject private var changesetOpenViewModel = ChangeSetOpenViewModel()
    @StateObject private var changeSetCloseViewModel = ChangeSetCloseViewModel()
    @StateObject private var modelInitializationViewModel = ModelInitializationViewModel()
    @StateObject private var sharedAppContextInitializationViewModel = SharedAppContextInitializationViewModel()
    
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
//                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!sharedAppData.isUploadReady)
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
                    ForEach(Constants.SelectedAccessibilityFeatureConfig.classes, id: \.self) { accessibilityFeatureClass in
                        Button(action: {
                            if self.selectedClasses.contains(accessibilityFeatureClass) {
                                self.selectedClasses.remove(accessibilityFeatureClass)
                            } else {
                                self.selectedClasses.insert(accessibilityFeatureClass)
                            }
                        }) {
                            Text(accessibilityFeatureClass.name)
                                .foregroundStyle(
                                    self.selectedClasses.contains(accessibilityFeatureClass)
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
                                width: SetupViewConstants.Constraints.profileIconSize,
                                height: SetupViewConstants.Constraints.profileIconSize
                            )
                            .bold()
                    }
                ,
                trailing:
                    NavigationLink(
                        destination: ARCameraView(
                            selectedClasses: Array(self.selectedClasses).sorted()
                        )
                    ) {
                        Text(SetupViewConstants.Texts.nextButton)
                            .foregroundStyle(isSelectionEmpty ? Color.gray : Color.primary)
                            .font(.headline)
                    }
                    .disabled(isSelectionEmpty)
            )
            /// Alert for changeset opening error
            .alert(SetupViewConstants.Texts.changesetOpeningErrorTitle, isPresented: $changesetOpenViewModel.showRetryAlert) {
                Button(SetupViewConstants.Texts.changesetOpeningRetryText) {
                    changesetOpenViewModel.update(isChangesetOpened: false, showRetryAlert: false, retryMessage: "")
                    
                    openChangeset()
                }
            } message: {
                Text(changesetOpenViewModel.retryMessage)
            }
            /// Alert for changeset closing error
            .alert(SetupViewConstants.Texts.changesetClosingErrorTitle, isPresented: $changeSetCloseViewModel.showRetryAlert) {
                Button(SetupViewConstants.Texts.changesetClosingRetryText) {
                    changeSetCloseViewModel.update(showRetryAlert: false, retryMessage: "")
                    
                    closeChangeset()
                }
            } message: {
                Text(changeSetCloseViewModel.retryMessage)
            }
            /// Alert for model initialization error
            .alert(SetupViewConstants.Texts.modelInitializationErrorTitle, isPresented: $modelInitializationViewModel.showRetryAlert) {
                Button(SetupViewConstants.Texts.modelInitializationRetryText) {
                    modelInitializationViewModel.update(areModelsInitialized: false, showRetryAlert: false, retryMessage: "")
                    
                    initializeModels()
                }
            }
            /// Alert for shared app context configuration error
            .alert(SetupViewConstants.Texts.sharedAppContextInitializationErrorTitle, isPresented: $sharedAppContextInitializationViewModel.showRetryAlert) {
                Button(SetupViewConstants.Texts.sharedAppContextInitializationRetryText) {
                    sharedAppContextInitializationViewModel.update(
                        isContextConfigured: false, showRetryAlert: false, retryMessage: ""
                    )
                    
                    configureSharedAppContext()
                }
            }
            .onAppear {
                if let _ = workspaceViewModel.changesetId {
                    changesetOpenViewModel.isChangesetOpened = true
                } else {
                    openChangeset()
                }
                if !modelInitializationViewModel.areModelsInitialized {
                    initializeModels()
                }
                if !sharedAppContextInitializationViewModel.isContextConfigured {
                    configureSharedAppContext()
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
        .environmentObject(self.sharedAppData)
        .environmentObject(self.sharedAppContext)
        .environmentObject(self.segmentationPipeline)
    }
    
    private func openChangeset() {
        Task {
            do {
                guard let workspaceId = workspaceViewModel.workspaceId else {
                    throw SetupViewError.noWorkspaceId
                }
                guard let accessToken = userStateViewModel.getAccessToken() else {
                    throw SetupViewError.authenticationError
                }
                
                let openedChangesetId = try await ChangesetService.shared.openChangesetAsync(
                    workspaceId: workspaceId, accessToken: accessToken
                )
                workspaceViewModel.updateChangeset(id: openedChangesetId)
                changesetOpenViewModel.isChangesetOpened = true
                sharedAppData.currentDatasetEncoder = DatasetEncoder(workspaceId: workspaceId, changesetId: openedChangesetId)
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    changesetOpenViewModel.update(
                        isChangesetOpened: false, showRetryAlert: true,
                        retryMessage: "\(SetupViewConstants.Texts.changesetOpeningRetryMessageText) \nError: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func closeChangeset() {
        Task {
            do {
                guard let changesetId = workspaceViewModel.changesetId else {
                    throw SetupViewError.changesetOpenFailed
                }
                guard let accessToken = userStateViewModel.getAccessToken() else {
                    throw SetupViewError.authenticationError
                }
                
                try await ChangesetService.shared.closeChangesetAsync(
                    changesetId: changesetId, accessToken: accessToken
                )
                sharedAppData.refreshData()
                sharedAppData.currentDatasetEncoder?.save()
                openChangeset()
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    changeSetCloseViewModel.update(
                        showRetryAlert: true,
                        retryMessage: "\(SetupViewConstants.Texts.changesetClosingRetryMessageText) \nError: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func initializeModels() {
        do {
            try segmentationPipeline.configure()
            modelInitializationViewModel.update(areModelsInitialized: true, showRetryAlert: false, retryMessage: "")
        } catch {
            /// Sleep for a short duration to avoid rapid retry loops
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                modelInitializationViewModel.update(
                    areModelsInitialized: false, showRetryAlert: true,
                    retryMessage: "\(SetupViewConstants.Texts.modelInitializationRetryMessageText) \nError: \(error.localizedDescription)")
            }
        }
    }
    
    private func configureSharedAppContext() {
        do {
            try sharedAppContext.configure()
            sharedAppContextInitializationViewModel.update(isContextConfigured: true, showRetryAlert: false, retryMessage: "")
        } catch {
            /// Sleep for a short duration to avoid rapid retry loops
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                sharedAppContextInitializationViewModel.update(
                    isContextConfigured: false, showRetryAlert: true,
                    retryMessage: "\(SetupViewConstants.Texts.sharedAppContextInitializationRetryMessageText) \nError: \(error.localizedDescription)")
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
//                .foregroundStyle(.accentColor)
            Text(SetupViewConstants.Texts.changesetInfoLearnMoreSheetTitle)
                .font(.headline)
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
            //                .foregroundStyle(.accentColor)
            Text(SetupViewConstants.Texts.selectClassesInfoLearnMoreSheetTitle)
                .font(.headline)
            Text(SetupViewConstants.Texts.selectClassesInfoLearnMoreSheetMessage)
                .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}
