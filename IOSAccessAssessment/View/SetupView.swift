//
//  SetupView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI

enum SetupViewConstants {
    enum Texts {
        static let setupViewTitle = "Setup"
        static let uploadChangesetTitle = "Upload Changeset"
        static let selectClassesText = "Select Classes to Identify"
        
        static let changesetOpeningErrorTitle = "Changeset failed to open. Please retry."
        static let changesetOpeningRetryText = "Retry"
        static let changesetOpeningRetryMessageText = "Failed to open changeset."
        static let changesetClosingErrorTitle = "Changeset failed to close. Please retry."
        static let changesetClosingRetryText = "Retry"
        static let changesetClosingRetryMessageText = "Failed to close changeset."
        
        static let confirmationDialogTitle = "Are you sure you want to log out?"
        static let confirmationDialogConfirmText = "Log out"
        static let confirmationDialogCancelText = "Cancel"
        
        static let nextButton = "Next"
    }
    
    enum Images {
        static let logoutIcon = "rectangle.portrait.and.arrow.right"
        static let uploadIcon = "arrow.up"
    }
    
    enum Colors {
        static let selectedClass = Color(red: 187/255, green: 134/255, blue: 252/255)
        static let unselectedClass = Color.white
    }
    
    enum Constraints {
        static let logoutIconSize: CGFloat = 20
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
    
    @EnvironmentObject var userState: UserStateViewModel
    @State private var showLogoutConfirmation = false
    
    @StateObject private var changesetOpenViewModel = ChangeSetOpenViewModel()
    @StateObject private var changeSetCloseViewModel = ChangeSetCloseViewModel()
    
    @StateObject private var sharedImageData: SharedImageData = SharedImageData()
    @StateObject private var segmentationPipeline: SegmentationPipeline = SegmentationPipeline()
    @StateObject private var depthModel: DepthModel = DepthModel()
    
    var body: some View {
        return NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(SetupViewConstants.Texts.uploadChangesetTitle)
                        .font(.subheadline)
                    
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
                
                Divider()
                
                Text(SetupViewConstants.Texts.selectClassesText)
                    .font(.subheadline)
//                    .foregroundColor(.gray)
                
                List {
                    ForEach(0..<Constants.ClassConstants.classNames.count, id: \.self) { index in
                        Button(action: {
                            if self.selection.contains(index) {
                                self.selection.remove(index)
                            } else {
                                self.selection.insert(index)
                            }
                        }) {
                            Text(Constants.ClassConstants.classNames[index])
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
                leading: Button(action: {
                    showLogoutConfirmation = true
                }) {
                    Image(systemName: SetupViewConstants.Images.logoutIcon)
                        .resizable()
                        .frame(
                            width: SetupViewConstants.Constraints.logoutIconSize,
                            height: SetupViewConstants.Constraints.logoutIconSize
                        )
                        .foregroundColor(.white)
                        .bold()
                },
                trailing:
                    NavigationLink(destination: ARContentView(selection: Array(selection))) {
                        Text(SetupViewConstants.Texts.nextButton)
                            .foregroundStyle(isSelectionEmpty ? Color.gray : Color.white)
                            .font(.headline)
                    }
                    .disabled(isSelectionEmpty)
            )
            // Alert for logout confirmation
            .alert(
                SetupViewConstants.Texts.confirmationDialogTitle,
                isPresented: $showLogoutConfirmation
            ) {
                Button(SetupViewConstants.Texts.confirmationDialogConfirmText, role: .destructive) {
                    userState.logout()
                }
                Button(SetupViewConstants.Texts.confirmationDialogCancelText, role: .cancel) { }
            }
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
        }
        .environmentObject(self.sharedImageData)
        .environmentObject(self.segmentationPipeline)
        .environmentObject(self.depthModel)
        .environment(\.colorScheme, .dark)
    }
    
    private func openChangeset() {
        ChangesetService.shared.openChangeset { result in
            switch result {
            case .success(let changesetId):
                print("Opened changeset with ID: \(changesetId)")
                DispatchQueue.main.async {
                    changesetOpenViewModel.isChangesetOpened = true
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
