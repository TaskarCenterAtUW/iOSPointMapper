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
    
    func workspaceSelected(id: String) {
        self.workspaceId = id
        self.isWorkspaceSelected = true
    }
    
    func updateChangeset(id: String) {
        self.changesetId = id
    }
    
    func clearWorkspaceSelection() {
        self.workspaceId = nil
        self.changesetId = nil
        self.isWorkspaceSelected = false
    }
}
