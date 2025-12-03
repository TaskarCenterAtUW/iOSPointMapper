//
//  WorkspaceListViewModel.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/31/25.
//

import Foundation

/**
    ViewModel to manage the state of workspace selection
 
    TODO: Utilize UserDefaults or Keychain to persist the selected workspace across app launches
 */
class WorkspaceViewModel: ObservableObject {
    
    @Published var isWorkspaceSelected: Bool = false
    
    var workspaceId: String? = nil
    
    init() {
    }
    
    func workspaceSelected(id: String) {
        self.workspaceId = id
        self.isWorkspaceSelected = true
    }
    
    func clearWorkspaceSelection() {
        self.workspaceId = nil
        self.isWorkspaceSelected = false
    }
}
