//
//  WorkspaceViewModel.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/31/25.
//

import Foundation

/**
    ViewModel to manage the state of workspace
 
    TODO: Utilize UserDefaults or Keychain to persist the selected workspace across app launches
 */
@MainActor
class WorkspaceViewModel: ObservableObject {
    @Published var isWorkspaceSelected: Bool = false
    
    /// TODO: Instead of storing selected workspace id and title separately, save a full Workspace object
    /// For UserDefaults, we can save all the parameters of the workspace (either separately or as a JSON string) and reconstruct the Workspace object when needed.
    var workspaceId: String? = nil
    var workspaceTitle: String? = nil
    
    var changesetId: String? = nil
    
    init() {
        if let savedWorkspaceId = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.selectedWorkspaceIdKey),
           let savedWorkspaceTitle = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.selectedWorkspaceTitleKey) {
            self.workspaceId = savedWorkspaceId
            self.workspaceTitle = savedWorkspaceTitle
            self.isWorkspaceSelected = true
        } else {
            self.workspaceId = nil
            self.workspaceTitle = nil
            self.isWorkspaceSelected = false
        }
    }
    
    func workspaceSelected(id: String, title: String) {
        self.workspaceId = id
        self.workspaceTitle = title
        self.isWorkspaceSelected = true
        UserDefaults.standard.set(workspaceId, forKey: Constants.UserDefaultsKeys.selectedWorkspaceIdKey)
        UserDefaults.standard.set(title, forKey: Constants.UserDefaultsKeys.selectedWorkspaceTitleKey)
    }
    
    func updateChangeset(id: String) {
        self.changesetId = id
    }
    
    func clearWorkspaceSelection() {
        self.workspaceId = nil
        self.changesetId = nil
        self.isWorkspaceSelected = false
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.selectedWorkspaceIdKey)
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.selectedWorkspaceTitleKey)
    }
}
