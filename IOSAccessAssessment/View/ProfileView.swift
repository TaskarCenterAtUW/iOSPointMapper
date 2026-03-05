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
        /// Enhanced Analysis
        static let enhancedAnalysisLabel = "Enhanced Analysis"
        static let enhancedAnalysisDescription = "Enable enhanced analysis features for better localization and attribute estimations."
        /// App Mode
        static let appModeSettingsLabel = "App Mode"
        static let appModeDescription = "Switch between different app modes"
        /// Enhanced Analysis Info Tip
        static let enhancedAnalysisInfoTipTitle = "Enhanced Analysis"
        static let enhancedAnalysisInfoTipMessage = """
            Enhanced analysis improves the accuracy of localization and attribute estimations for accessibility features.
            """
        static let enhancedAnalysisInfoTipLearnButtonTitle = "Learn More"
        /// Enhanced Analysis Learn More Sheet
        static let enhancedAnalysisLearnMoreSheetMessage = """
            Enhanced analysis uses advanced Augmented Reality-based scene understanding to improve the accuracy of localization and attribute estimations for accessibility features.
            
            Enabling this feature will increase processing time and battery usage.
            """
        /// App Mode Info Tip
        static let appModeInfoTipTitle = "App Mode"
        static let appModeInfoTipMessage = """
            App mode allows you to switch between different modes: Standard Mode and Test Mode. 
            """
        static let appModeLearnMoreButtonTitle = "Learn More"
        static let appModeLearnMoreSheetMessage = """
            App mode allows you to switch between different modes:
            
            - Standard Mode: The default mode to capture new data and perform mapping in real-time, providing an interactive experience.
            - Test Mode: Developmental mode to simulate mapping by using existing locally saved input data to perform mapping without needing to capture new data.
            """
        
        /// Log out
        static let logoutButtonText = "Log out"
        static let confirmationDialogTitle = "Are you sure you want to log out?"
        static let confirmationDialogConfirmText = "Log out"
        static let confirmationDialogCancelText = "Cancel"
    }
    
    enum Images {
        static let logoutIcon = "rectangle.portrait.and.arrow.right"
        
        static let infoIcon: String = "info.circle"
    }
    
    enum Constraints {
        static let profileIconSize: CGFloat = 20
    }
    
    enum Identifiers {
        static let enhancedAnalysisInfoTipLearnMoreActionId: String = "enhanced-analysis-learn-more"
        static let appModeLearnMoreActionId: String = "app-mode-learn-more"
    }
}

struct EnhancedAnalysisInfoTip: Tip {
    var title: Text {
        Text(ProfileViewConstants.Texts.enhancedAnalysisInfoTipTitle)
    }
    var message: Text? {
        Text(ProfileViewConstants.Texts.enhancedAnalysisInfoTipMessage)
    }
    var image: Image? {
        Image(systemName: ProfileViewConstants.Images.infoIcon)
            .resizable()
//            .frame(width: 30, height: 30)
    }
    var actions: [Action] {
        // Define a learn more button.
        Action(
            id: ProfileViewConstants.Identifiers.enhancedAnalysisInfoTipLearnMoreActionId,
            title: ProfileViewConstants.Texts.enhancedAnalysisInfoTipLearnButtonTitle
        )
    }
}

struct AppModeInfoTip: Tip {
    var title: Text {
        Text(ProfileViewConstants.Texts.appModeInfoTipTitle)
    }
    var message: Text? {
        Text(ProfileViewConstants.Texts.appModeInfoTipMessage)
    }
    var image: Image? {
        Image(systemName: ProfileViewConstants.Images.infoIcon)
            .resizable()
    }
    var actions: [Action] {
        // Define a learn more button.
        Action(
            id: ProfileViewConstants.Identifiers.enhancedAnalysisInfoTipLearnMoreActionId,
            title: ProfileViewConstants.Texts.appModeLearnMoreButtonTitle
        )
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
    var enhancedAnalysisInfoTip = EnhancedAnalysisInfoTip()
    @State private var showEnhancedAnalysisLearnMoreSheet = false
    var appModeInfoTip = AppModeInfoTip()
    @State private var showAppModeLearnMoreSheet = false
    
    var body: some View {
        ScrollView(.vertical) {
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
                
                VStack {
                    HStack {
                        Text(ProfileViewConstants.Texts.advancedSettingsTitle)
                            .font(.headline)
                        Spacer()
                    }
                    
                    HStack {
                        HStack {
                            Text(ProfileViewConstants.Texts.enhancedAnalysisLabel)
                                .font(.subheadline)
                            Button(action: {
                                showEnhancedAnalysisLearnMoreSheet = true
                            }) {
                                Image(systemName: ProfileViewConstants.Images.infoIcon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Spacer()
                        }
                        
                        Spacer()
                        
                        Toggle(isOn: $userState.isEnhancedAnalysisEnabled) {
                            Text("")
                        }
                        .tint(.blue)
                    }
                    .padding(.top, 20)
                    TipView(enhancedAnalysisInfoTip, arrowEdge: .top) { action in
                        if action.id == ProfileViewConstants.Identifiers.enhancedAnalysisInfoTipLearnMoreActionId {
                            showEnhancedAnalysisLearnMoreSheet = true
                        }
                    }
                    
                    HStack {
                        HStack {
                            Text(ProfileViewConstants.Texts.appModeSettingsLabel)
                                .font(.subheadline)
                            Button(action: {
                                showAppModeLearnMoreSheet = true
                            }) {
                                Image(systemName: ProfileViewConstants.Images.infoIcon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            Spacer()
                        }
                        
                        Spacer()
                        
                        Picker(userState.appMode.description, selection: $userState.appMode) {
                            ForEach(AppMode.allCases) { mode in
                                Text(mode.description).tag(mode)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                    TipView(appModeInfoTip, arrowEdge: .top) { action in
                        if action.id == ProfileViewConstants.Identifiers.appModeLearnMoreActionId {
                            showAppModeLearnMoreSheet = true
                        }
                    }
                }
                
                Divider()
                
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
            .padding(.horizontal, 10)
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
        .sheet(isPresented: $showEnhancedAnalysisLearnMoreSheet) {
            EnhancedAnalysisLearnMoreSheetView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAppModeLearnMoreSheet) {
            AppModeLearnMoreSheetView()
                .presentationDetents([.medium, .large])
        }
    }
}

struct EnhancedAnalysisLearnMoreSheetView: View {
    @Environment(\.dismiss)
    var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
//            Image(systemName: "number")
//                .resizable()
//                .scaledToFit()
//                .frame(width: 160)
//                .foregroundStyle(.accentColor)
            Text(ProfileViewConstants.Texts.enhancedAnalysisInfoTipTitle)
                .font(.headline)
            Text(ProfileViewConstants.Texts.enhancedAnalysisLearnMoreSheetMessage)
                .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}

struct AppModeLearnMoreSheetView: View {
    @Environment(\.dismiss)
    var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text(ProfileViewConstants.Texts.appModeInfoTipTitle)
                .font(.headline)
            Text(ProfileViewConstants.Texts.appModeLearnMoreSheetMessage)
                .foregroundStyle(.secondary)
            Button("Dismiss") {
                dismiss()
            }
        }
        .padding(.horizontal, 40)
    }
}

