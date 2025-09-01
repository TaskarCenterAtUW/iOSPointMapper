//
//  ProfileView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/31/25.
//

import SwiftUI

enum ProfileViewConstants {
    enum Texts {
        static let profileTitle: String = "Profile"
        static let usernameLabel: String = "Username: "
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
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text(ProfileViewConstants.Texts.profileTitle)
                .font(.title)
                .bold()
                .padding(.bottom, 20)
            
            Text("\(ProfileViewConstants.Texts.usernameLabel)\(username)")
//                .padding()
                .padding(.bottom, 40)
            
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
        .onAppear {
            username = userState.getUsername() ?? ProfileViewConstants.Texts.usernamePlaceholder
        }
        .alert(
            SetupViewConstants.Texts.confirmationDialogTitle,
            isPresented: $showLogoutConfirmation
        ) {
            Button(SetupViewConstants.Texts.confirmationDialogConfirmText, role: .destructive) {
                userState.logout()
            }
            Button(SetupViewConstants.Texts.confirmationDialogCancelText, role: .cancel) { }
        }
    }
}
