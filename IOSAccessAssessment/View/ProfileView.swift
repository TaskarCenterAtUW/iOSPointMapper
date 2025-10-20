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
        static let profileTitle: String = "Profile"
        static let usernameLabel: String = "Username: "
        static let switchWorkspaceButtonText = "Switch Workspace"
        static let logoutButtonText = "Log out"
        
        static let usernamePlaceholder = "User"
        
        static let confirmationDialogTitle = "Are you sure you want to log out?"
        static let confirmationDialogConfirmText = "Log out"
        static let confirmationDialogCancelText = "Cancel"
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
//                .padding()
                .padding(.bottom, 40)
            
            HStack {
                Spacer()
                Button(action: {
                    showWorkspaceLearnMoreSheet = true
                }) {
                    Image(systemName: WorkspaceSelectionViewConstants.Images.infoIcon)
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }
            .overlay(
                Button(action: {
                    workspaceViewModel.clearWorkspaceSelection()
                    self.dismiss()
                }) {
                    Text(ProfileViewConstants.Texts.switchWorkspaceButtonText)
                        .foregroundColor(.white)
                        .bold()
                        .padding()
                }
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            )
            .padding(.vertical, 20)
            TipView(workspaceInfoTip, arrowEdge: .top) { action in
                if action.id == WorkspaceSelectionViewConstants.Identifiers.workspaceInfoTipLearnMoreActionId {
                    showWorkspaceLearnMoreSheet = true
                }
            }
            
            Button(action: {
                showLogoutConfirmation = true
            }) {
                HStack {
                    Text(ProfileViewConstants.Texts.logoutButtonText)
                        .foregroundColor(.white)
                        .bold()
                    Image(systemName: SetupViewConstants.Images.logoutIcon)
                        .resizable()
                        .frame(
                            width: SetupViewConstants.Constraints.logoutIconSize,
                            height: SetupViewConstants.Constraints.logoutIconSize
                        )
                        .foregroundColor(.white)
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
        }
    }
}
