//
//  SetupView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI

struct SetupView: View {

    @State private var selection = Set<Int>()
    @State private var showLogoutConfirmation = false
    @EnvironmentObject var userState: UserStateViewModel
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Setup View")
                    .font(.largeTitle)
                    .padding(.bottom, 5)
                
                Text("Select Classes to Identify")
                    .font(.headline)
                    .foregroundColor(.gray)
                
                List {
                    ForEach(0..<Constants.ClassConstants.classes.count, id: \.self) { index in
                        Button(action: {
                            if self.selection.contains(index) {
                                self.selection.remove(index)
                            } else {
                                self.selection.insert(index)
                            }
                        }) {
                            Text(Constants.ClassConstants.classes[index])
                                .foregroundColor(self.selection.contains(index) ?
                                                 Color(red: 187/255, green: 134/255, blue: 252/255) : .white)
                        }
                    }
                }
//                .environment(\.colorScheme, .dark)
            }
            .padding()
            .navigationBarTitle("Setup View", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(action: {
                    showLogoutConfirmation = true
                }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.white)
                        .bold()
                },
                trailing: NavigationLink(destination: ContentView(selection: Array(selection))) {
                    Text("Next").foregroundStyle(Color.white).font(.headline)
                }
            )
            .confirmationDialog(
                "Are you sure you want to log out?",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Log out", role: .destructive) { userState.logout() }
                Button("Cancel", role: .cancel) { }
            }
        }.environment(\.colorScheme, .dark)
    }
}

