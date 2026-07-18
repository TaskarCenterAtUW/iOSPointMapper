//
//  SetupView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI
import TipKit
import PointNMapShared

enum SetupViewConstants {
    enum Texts {
        static let setupViewTitle = "Setup"
        static let selectedWorkspaceTitle = "Selected Workspace"
        static let uploadChangesetTitle = "Upload Changeset"
        static let selectClassesText = "Select Feature Types to Map"
        
        /// Alerts
        static let changesetOpeningErrorTitle = "Changeset failed to open. Please retry."
        static let changesetOpeningRetryText = "Retry"
        static let changesetOpeningRetryMessageText = "Failed to open changeset."
        static let changesetOpeningBackText = "Back"
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
        
        /// Class Selection
        static let classSelectionColorHintIcon = "circle.fill"
        static let classSelectionColorHintBorderIcon = "circle"
        
        /// Attribute Selection
        static let attributeSelectedStatusIcon = "checkmark.circle.fill"
        static let attributeUnselectedStatusIcon = "circle"
        static let attributeSectionExpandedIcon = "chevron.up.circle"
        static let attributeSectionCollapsedIcon = "chevron.down.circle"
        
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
    case currentDatasetInitializationFailed
    case currentDatasetSaveFailed
    
    var errorDescription: String? {
        switch self {
        case .noWorkspaceId:
            return "Workspace ID is missing."
        case .changesetOpenFailed:
            return "Failed to open changeset."
        case .authenticationError:
            return "Authentication error. Please log in again."
        case .currentDatasetInitializationFailed:
            return "Failed to initialize local dataset."
        case .currentDatasetSaveFailed:
            return "Failed to save local dataset."
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

class CurrentDatasetStatusViewModel: ObservableObject {
    @Published var isFailed: Bool = false
    @Published var errorMessage: String = ""
    
    func update(isFailed: Bool, errorMessage: String) {
        self.isFailed = isFailed
        self.errorMessage = errorMessage
    }
}

struct SetupView: View {
    @State private var selectedClasses = Set<AccessibilityFeatureClass>()
    @State private var selectedAttributesByClass = [AccessibilityFeatureClass: Set<AccessibilityFeatureAttribute>]()
    private var isSelectionEmpty: Bool {
        return (self.selectedClasses.count == 0)
    }
    @State private var expandedAttributeSections: Set<AccessibilityFeatureClass> = []
    
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @EnvironmentObject var userStateViewModel: UserStateViewModel
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var sharedAppData: SharedAppData = SharedAppData()
    @StateObject private var sharedAppContext: SharedAppContext = SharedAppContext()
    @StateObject private var segmentationPipeline: SegmentationARPipeline = SegmentationARPipeline()
    
    @StateObject private var changesetOpenViewModel = ChangeSetOpenViewModel()
    @StateObject private var changeSetCloseViewModel = ChangeSetCloseViewModel()
    @StateObject private var modelInitializationViewModel = ModelInitializationViewModel()
    @StateObject private var sharedAppContextInitializationViewModel = SharedAppContextInitializationViewModel()
    @StateObject private var currentDatasetStatusViewModel = CurrentDatasetStatusViewModel()
    
    var changesetInfoTip = ChangesetInfoTip()
    @State private var showChangesetLearnMoreSheet = false
    var selectClassesInfoTip = SelectClassesInfoTip()
    @State private var showSelectClassesLearnMoreSheet = false
    
    var body: some View {
        return NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    HStack {
                        Text(SetupViewConstants.Texts.selectedWorkspaceTitle)
                            .font(.headline)
                        Spacer()
                        Text(workspaceViewModel.workspaceTitle ?? "N/A")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                
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
//                if currentDatasetStatusViewModel.isFailed {
//                    Text(currentDatasetStatusViewModel.errorMessage)
//                        .foregroundStyle(.red)
//                }
                
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
                    ForEach(SharedAppConstants.SelectedAccessibilityFeatureConfig.classes, id: \.self) { accessibilityFeatureClass in
                        listElementView(for: accessibilityFeatureClass)
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
                    NavigationLink(destination: mappingDestination) {
                        Text(SetupViewConstants.Texts.nextButton)
                            .foregroundStyle(isSelectionEmpty ? Color.gray : Color.primary)
                            .font(.headline)
                    }
                    .disabled(isSelectionEmpty)
            )
            /// Alert for changeset opening error (Contains the retry and the back button)
            .alert(SetupViewConstants.Texts.changesetOpeningErrorTitle, isPresented: $changesetOpenViewModel.showRetryAlert) {
                Button(SetupViewConstants.Texts.changesetOpeningBackText, role: .destructive) {
                    changesetOpenViewModel.update(isChangesetOpened: false, showRetryAlert: false, retryMessage: "")
                    
                    workspaceViewModel.clearWorkspaceSelection()
                }
                Button(SetupViewConstants.Texts.changesetOpeningRetryText, role: .cancel) {
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
    
    @ViewBuilder
    private func listElementView(for accessibilityFeatureClass: AccessibilityFeatureClass) -> some View {
        HStack {
            let isClassSelected = self.selectedClasses.contains(accessibilityFeatureClass)
            let attributes = Array(accessibilityFeatureClass.kind.attributes).sorted(by: { $0.name < $1.name })
            let hasAttributes = !attributes.isEmpty
            let isExpanded = isAttributeSectionExpanded(for: accessibilityFeatureClass)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Button(action: {
                        toggleClass(accessibilityFeatureClass)
                    }) {
                        HStack {
                            Text(accessibilityFeatureClass.name)
                                .foregroundStyle(
                                    isClassSelected
                                    ? SetupViewConstants.Colors.selectedClass
                                    : SetupViewConstants.Colors.unselectedClass
                                )
                            Spacer()
                            
                            Image(systemName: SetupViewConstants.Images.classSelectionColorHintIcon)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(Color(UIColor(ciColor: accessibilityFeatureClass.color)))
                                .overlay(
                                    Image(systemName: SetupViewConstants.Images.classSelectionColorHintBorderIcon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .foregroundStyle(
                                            isClassSelected
                                            ? SetupViewConstants.Colors.selectedClass
                                            : SetupViewConstants.Colors.unselectedClass
                                        )
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if hasAttributes && isClassSelected {
                        Button(action: {
                            toggleAttributeSectionExpansion(for: accessibilityFeatureClass)
                        }) {
                            HStack(spacing: 4) {
                                Text(attributeSelectionSummary(for: accessibilityFeatureClass))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Image(systemName: isExpanded ? SetupViewConstants.Images.attributeSectionExpandedIcon : SetupViewConstants.Images.attributeSectionCollapsedIcon)
                                    .imageScale(.medium)
                            }
                        }
                    }
                }
                
                if hasAttributes && isExpanded && isClassSelected {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(attributes, id: \.self) { attribute in
                            Button(action: {
                                toggleAttribute(attribute, for: accessibilityFeatureClass)
                            }) {
                                HStack {
                                    Text(attribute.name)
                                        .font(.subheadline)
                                    Spacer()
                                    Image(systemName: isAttributeSelected(attribute, for: accessibilityFeatureClass) ? SetupViewConstants.Images.attributeSelectedStatusIcon : SetupViewConstants.Images.attributeUnselectedStatusIcon
                                    )
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)
//                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private var mappingDestination: some View {
        if userStateViewModel.appMode == .standard {
            ARCameraView(
                selectedClasses: Array(self.selectedClasses).sorted(),
                selectedAttributesByClass: self.selectedAttributesByClass
            )
        } else {
            TestEnvironmentListView(
                selectedClasses: Array(self.selectedClasses).sorted(),
                selectedAttributesByClass: self.selectedAttributesByClass
            )
        }
    }
    
    private func toggleClass(_ accessibilityFeatureClass: AccessibilityFeatureClass) {
        if self.selectedClasses.contains(accessibilityFeatureClass) {
            self.selectedClasses.remove(accessibilityFeatureClass)
            
            /// Clear the selected attributes for the class when it is deselected
//            self.selectedAttributesByClass[accessibilityFeatureClass] = nil
            self.expandedAttributeSections.remove(accessibilityFeatureClass)
        } else {
            self.selectedClasses.insert(accessibilityFeatureClass)
            
            if !self.selectedAttributesByClass.contains(where: { $0.key == accessibilityFeatureClass }) {
                /// Add all the attributes for the class when it is selected
                self.selectedAttributesByClass[accessibilityFeatureClass] = Set(accessibilityFeatureClass.kind.attributes)
            }
        }
    }
    
    private func toggleAttribute(
        _ attribute: AccessibilityFeatureAttribute, for accessibilityFeatureClass: AccessibilityFeatureClass
    ) {
        var selectedAttributes = selectedAttributesByClass[accessibilityFeatureClass, default: []]
        
        if selectedAttributes.contains(attribute) {
            selectedAttributes.remove(attribute)
        } else {
            selectedAttributes.insert(attribute)
        }
        
        selectedAttributesByClass[accessibilityFeatureClass] = selectedAttributes
    }
    
    private func isAttributeSelected(
        _ attribute: AccessibilityFeatureAttribute,
        for accessibilityFeatureClass: AccessibilityFeatureClass
    ) -> Bool {
        selectedAttributesByClass[accessibilityFeatureClass, default: []].contains(attribute)
    }
    
    private func toggleAttributeSectionExpansion(for accessibilityFeatureClass: AccessibilityFeatureClass) {
//        withAnimation {
        if expandedAttributeSections.contains(accessibilityFeatureClass) {
            expandedAttributeSections.remove(accessibilityFeatureClass)
        } else {
            expandedAttributeSections.insert(accessibilityFeatureClass)
        }
//        }
    }
    
    private func isAttributeSectionExpanded(for accessibilityFeatureClass: AccessibilityFeatureClass) -> Bool {
        expandedAttributeSections.contains(accessibilityFeatureClass)
    }
    
    private func attributeSelectionSummary(
        for accessibilityFeatureClass: AccessibilityFeatureClass
    ) -> String {
        let attributes = accessibilityFeatureClass.kind.attributes
        guard !attributes.isEmpty else {
            return ""
        }
        let selectedCount = selectedAttributesByClass[accessibilityFeatureClass, default: []].count

        if selectedCount == attributes.count {
            return "All"
        } else if selectedCount == 0 {
            return "None"
        } else {
            return "\(selectedCount)/\(attributes.count)"
        }
    }
    
    private func openChangeset() {
        Task {
            do {
                let selectedEnvironment = userStateViewModel.selectedEnvironment
                guard let workspaceId = workspaceViewModel.workspaceId else {
                    throw SetupViewError.noWorkspaceId
                }
                guard let accessToken = userStateViewModel.getAccessToken() else {
                    throw SetupViewError.authenticationError
                }
                
                let openedChangesetId = try await ChangesetService.shared.openChangesetAsync(
                    workspaceId: workspaceId, accessToken: accessToken,
                    environment: userStateViewModel.selectedEnvironment
                )
                workspaceViewModel.updateChangeset(id: openedChangesetId)
                changesetOpenViewModel.isChangesetOpened = true
                try initializeCurrentDataset(
                    apiEnvironment: selectedEnvironment,
                    workspaceId: workspaceId, changeSetId: openedChangesetId
                )
            } catch SetupViewError.currentDatasetInitializationFailed {
                setCurrentDatasetStatusErrorHint(SetupViewError.currentDatasetInitializationFailed.localizedDescription)
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    changesetOpenViewModel.update(
                        isChangesetOpened: false, showRetryAlert: true,
                        retryMessage: "\(SetupViewConstants.Texts.changesetOpeningRetryMessageText) \nError: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func initializeCurrentDataset(apiEnvironment: APIEnvironment, workspaceId: String, changeSetId: String) throws {
        do {
            sharedAppData.currentDatasetEncoder = try DatasetEncoder(
                apiEnvironment: apiEnvironment,
                workspaceId: workspaceId, changesetId: changeSetId
            )
        } catch {
            /// Handle this in the main catch block
            throw SetupViewError.currentDatasetInitializationFailed
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
                await sharedAppData.refreshQueue()
                openChangeset()
                try saveCurrentDataset()
            } catch SetupViewError.currentDatasetSaveFailed {
                setCurrentDatasetStatusErrorHint(SetupViewError.currentDatasetSaveFailed.localizedDescription)
            } catch {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    changeSetCloseViewModel.update(
                        showRetryAlert: true,
                        retryMessage: "\(SetupViewConstants.Texts.changesetClosingRetryMessageText) \nError: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func saveCurrentDataset() throws {
        do {
            guard let currentDatasetEncoder = sharedAppData.currentDatasetEncoder else {
                throw SetupViewError.currentDatasetSaveFailed
            }
            try currentDatasetEncoder.save()
        } catch {
            /// Handle this in the main catch block
            throw SetupViewError.currentDatasetSaveFailed
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
    
    /// Set text for 2 seconds, and then fall back to placeholder
    private func setCurrentDatasetStatusErrorHint(_ text: String) {
        print("CurrentDatasetStatus Error: \(text)")
        currentDatasetStatusViewModel.update(isFailed: true, errorMessage: text)
        Task {
            try await Task.sleep(for: .seconds(2))
            currentDatasetStatusViewModel.update(isFailed: false, errorMessage: "")
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
