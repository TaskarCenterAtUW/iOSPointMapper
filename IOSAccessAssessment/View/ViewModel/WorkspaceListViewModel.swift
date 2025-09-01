//
//  WorkspaceListViewModel.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/31/25.
//

import Foundation

/**
    ViewModel to manage the state of workspace selection
 */
class WorkspaceViewModel: ObservableObject {
    
    @Published var isWorkspaceSelected: Bool = false
    
    var workspaceId: String? = nil
    
    init() {
        // User Defaults to check if workspace is selected
//        if let savedWorkspaceId = UserDefaults.standard.string(forKey: "selectedWorkspaceId") {
//            self.workspaceId = savedWorkspaceId
//            self.isWorkspaceSelected = true
//        } else {
//            self.isWorkspaceSelected = false
//            self.workspaceId = nil
//        }
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
