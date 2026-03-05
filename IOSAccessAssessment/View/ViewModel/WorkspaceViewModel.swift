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
class WorkspaceViewModel: ObservableObject {
    @Published var isWorkspaceSelected: Bool = false
    
    var workspaceId: String? = nil
    var changesetId: String? = nil
    
    init() {
        if let savedWorkspaceId = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.selectedWorkspaceIdKey) {
            self.workspaceId = savedWorkspaceId
            self.isWorkspaceSelected = true
        } else {
            self.workspaceId = nil
            self.isWorkspaceSelected = false
        }
    }
    
    func workspaceSelected(id: String) {
        self.workspaceId = id
        self.isWorkspaceSelected = true
        UserDefaults.standard.set(workspaceId, forKey: Constants.UserDefaultsKeys.selectedWorkspaceIdKey)
    }
    
    func updateChangeset(id: String) {
        self.changesetId = id
    }
    
    func clearWorkspaceSelection() {
        self.workspaceId = nil
        self.changesetId = nil
        self.isWorkspaceSelected = false
        UserDefaults.standard.removeObject(forKey: Constants.UserDefaultsKeys.selectedWorkspaceIdKey)
    }
}
