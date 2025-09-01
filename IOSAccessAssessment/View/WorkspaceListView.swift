//
//  WorkspaceListView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 8/25/25.
//

import SwiftUI

struct WorkspaceListView: View {
    @State var workspaces: [Workspace] = []
    
    var body: some View {
        Text("Workspace List View")
        .onAppear {
            
        }
    }
    
    func loadWorkspaces() {
        
    }
}
