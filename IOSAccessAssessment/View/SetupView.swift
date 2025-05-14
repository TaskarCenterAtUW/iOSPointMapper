//
//  SetupView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI

struct SetupView: View {
    
    private enum SetupViewConstants {
        enum Texts {
            static let setupViewTitle = "Setup"
            static let uploadChangesetTitle = "Upload Changeset"
            static let selectClassesText = "Select Classes to Identify"
            static let changesetOpeningErrorText = "Changeset failed to open. Please retry."
            static let changesetOpeningRetryText = "Retry"
            static let changesetClosingErrorText = "Changeset failed to close. Please retry."
            static let changesetClosingRetryText = "Retry"
            static let confirmationDialogTitle = "Are you sure you want to log out?"
            static let confirmationDialogConfirmText = "Log out"
            static let confirmationDialogCancelText = "Cancel"
            static let nextButton = "Next"
        }
        
        enum Images {
            static let logoutIcon = "rectangle.portrait.and.arrow.right"
        }
        
        enum Colors {
            static let selectedClass = Color(red: 187/255, green: 134/255, blue: 252/255)
            static let unselectedClass = Color.white
        }
        
        enum Constraints {
            static let logoutIconSize: CGFloat = 20
        }
    }
    
    @State private var isChangesetOpened = false
    @State private var showOpeningRetryAlert = false
    @State private var openRetryMessage = ""
//    @State private var isChangesetClosed = false
    @State private var showClosingRetryAlert = false
    @State private var closeRetryMessage = ""

    @State private var selection = Set<Int>()
    private var isSelectionEmpty: Bool {
        return (self.selection.count == 0)
    }
    @State private var showLogoutConfirmation = false
    @EnvironmentObject var userState: UserStateViewModel
    
    @StateObject private var sharedImageData: SharedImageData = SharedImageData()
    @StateObject private var segmentationPipeline: SegmentationPipeline = SegmentationPipeline()
    @StateObject private var depthModel: DepthModel = DepthModel()
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    Text(SetupViewConstants.Texts.uploadChangesetTitle)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Button (action: {
                        print("Uploading changeset...")
                        closeChangeset()
                    }) {
                        Image(systemName: "arrow.up")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
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
                    NavigationLink(destination: ContentView(selection: Array(selection))) {
                        Text(SetupViewConstants.Texts.nextButton)
                            .foregroundStyle(isSelectionEmpty ? Color.gray : Color.white)
                            .font(.headline)
                    }
                    .disabled(isSelectionEmpty)
            )
            .alert(
                SetupViewConstants.Texts.confirmationDialogTitle,
                isPresented: $showLogoutConfirmation
            ) {
                Button(SetupViewConstants.Texts.confirmationDialogConfirmText, role: .destructive) {
                    userState.logout()
                }
                Button(SetupViewConstants.Texts.confirmationDialogCancelText, role: .cancel) { }
            }
            .alert(SetupViewConstants.Texts.changesetOpeningErrorText, isPresented: $showOpeningRetryAlert) {
                Button(SetupViewConstants.Texts.changesetOpeningRetryText) {
                    isChangesetOpened = false
                    openRetryMessage = ""
                    showOpeningRetryAlert = false
                    
                    openChangeset()
                }
            } message: {
                Text(openRetryMessage)
            }
            .alert(SetupViewConstants.Texts.changesetClosingErrorText, isPresented: $showClosingRetryAlert) {
                Button(SetupViewConstants.Texts.changesetClosingRetryText) {
                    closeRetryMessage = ""
                    showClosingRetryAlert = false
                    
                    closeChangeset()
                }
            } message: {
                Text(closeRetryMessage)
            }
            .onAppear {
                // This refresh is done asynchronously, because frames get added from the ContentView even after the refresh
                // This kind of delay should be fine, since the very first few frames of capture may not be necessary.
                // MARK: Discuss on the possibility of having an explicit refresh
                // instead of always refreshing when we end up in SetupView (could happen accidentally)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                    print("Setup View: refreshing sharedImageData")
                    self.sharedImageData.refreshData()
                })
                openChangeset()
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
                isChangesetOpened = true
            case .failure(let error):
                openRetryMessage = "Failed to open changeset. Error: \(error.localizedDescription)"
                isChangesetOpened = false
                showOpeningRetryAlert = true
            }
        }
    }
    
    private func closeChangeset() {
        ChangesetService.shared.closeChangeset { result in
            switch result {
            case .success:
                print("Changeset closed successfully.")
            case .failure(let error):
                closeRetryMessage = "Failed to close changeset: \(error.localizedDescription)"
                showClosingRetryAlert = true
            }
        }
    }
}
