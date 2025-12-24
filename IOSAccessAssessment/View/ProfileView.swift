//
//  ProfileView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/31/25.
//

import SwiftUI
import TipKit

enum ProfileViewConstants {
    enum Texts {
        /// User Details
        static let profileTitle: String = "User Settings"
        static let usernameLabel: String = "Username: "
        static let usernamePlaceholder = "User"
        
        /// Workspace Settings
        static let workspaceSettingsTitle = "Workspace Settings"
        static let switchWorkspaceLabel = "Switch Workspace"
        static let switchWorkspaceDescription = "Switch to a different workspace to access its resources."
        static let switchWorkspaceButtonText = "Switch"
        
        /// Advanced Settings
        static let advancedSettingsTitle = "Advanced Settings"
        static let enhancedAnalysisLabel = "Enhanced Analysis"
        static let enhancedAnalysisDescription = "Enable enhanced analysis features for better localization and attribute estimations."
        
        /// Log out
        static let logoutButtonText = "Log out"
        static let confirmationDialogTitle = "Are you sure you want to log out?"
        static let confirmationDialogConfirmText = "Log out"
        static let confirmationDialogCancelText = "Cancel"
    }
    
    enum Images {
        static let logoutIcon = "rectangle.portrait.and.arrow.right"
    }
    
    enum Constraints {
        static let profileIconSize: CGFloat = 20
    }
}

struct ProfileView: View {
    @State private var username: String = ""
    @State private var showLogoutConfirmation: Bool = false
    
    @EnvironmentObject var userState: UserStateViewModel
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    @Environment(\.dismiss) var dismiss
    
    var workspaceInfoTip = WorkspaceInfoTip()
    @State private var showWorkspaceLearnMoreSheet = false
    
    var body: some View {
        VStack {
            Text("\(ProfileViewConstants.Texts.usernameLabel)\(username)")
                .padding(.top, 20)
                .padding(.bottom, 40)
            
            Divider()
            
            VStack {
                HStack {
                    Text(ProfileViewConstants.Texts.workspaceSettingsTitle)
                        .font(.headline)
                    Spacer()
                }
                HStack {
                    HStack {
                        Text(ProfileViewConstants.Texts.switchWorkspaceLabel)
                            .font(.subheadline)
                        Button(action: {
                            showWorkspaceLearnMoreSheet = true
                        }) {
                            Image(systemName: WorkspaceSelectionViewConstants.Images.infoIcon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        workspaceViewModel.clearWorkspaceSelection()
                        self.dismiss()
                    }) {
                        Text(ProfileViewConstants.Texts.switchWorkspaceButtonText)
                            .foregroundStyle(.white)
                            .bold()
                            .padding()
                    }
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(.vertical, 20)
                TipView(workspaceInfoTip, arrowEdge: .top) { action in
                    if action.id == WorkspaceSelectionViewConstants.Identifiers.workspaceInfoTipLearnMoreActionId {
                        showWorkspaceLearnMoreSheet = true
                    }
                }
            }
            
            Divider()
            
            Button(action: {
                showLogoutConfirmation = true
            }) {
                HStack {
                    Text(ProfileViewConstants.Texts.logoutButtonText)
                        .foregroundStyle(.white)
                        .bold()
                    Image(systemName: ProfileViewConstants.Images.logoutIcon)
                        .resizable()
                        .frame(
                            width: ProfileViewConstants.Constraints.profileIconSize,
                            height: ProfileViewConstants.Constraints.profileIconSize
                        )
                        .foregroundStyle(.white)
                        .bold()
                }
                .padding()
            }
            .background(Color.blue)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            Spacer()
        }
        .navigationBarTitle(ProfileViewConstants.Texts.profileTitle, displayMode: .inline)
        .onAppear {
            username = userState.getUsername() ?? ProfileViewConstants.Texts.usernamePlaceholder
        }
        .alert(
            SetupViewConstants.Texts.confirmationDialogTitle,
            isPresented: $showLogoutConfirmation
        ) {
            Button(SetupViewConstants.Texts.confirmationDialogConfirmText, role: .destructive) {
                workspaceViewModel.clearWorkspaceSelection()
                userState.logout()
            }
            Button(SetupViewConstants.Texts.confirmationDialogCancelText, role: .cancel) { }
        }
        .sheet(isPresented: $showWorkspaceLearnMoreSheet) {
            WorkspaceSelectionLearnMoreSheetView()
                .presentationDetents([.medium, .large])
        }
    }
}
