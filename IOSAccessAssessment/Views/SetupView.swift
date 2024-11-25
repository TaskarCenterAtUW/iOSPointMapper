//
//  SetupView.swift
//  IOSAccessAssessment
//
//  Created by Kohei Matsushima on 2024/03/29.
//

import SwiftUI

struct SetupView: View {
    
    private enum SetupViewConstants {
        enum Texts {
            static let setupViewTitle = "Setup"
            static let selectClassesText = "Select Classes to Identify"
            static let confirmationDialogTitle = "Are you sure you want to log out?"
            static let confirmationDialogConfirmText = "Log out"
            static let confirmationDialogCancelText = "Cancel"
            static let nextButton = "Next"
        }
        
        enum Images {
            static let logoutIcon = "rectangle.portrait.and.arrow.right"
        }
        
        enum Colors {
            static let selectedClass = Color(red: 187/255, green: 134/255, blue: 252/255)
            static let unselectedClass = Color.white
        }
        
        enum Constraints {
            static let logoutIconSize: CGFloat = 20
        }
    }

    @State private var selection = Set<Int>()
    @State private var showLogoutConfirmation = false
    @EnvironmentObject var userState: UserStateViewModel
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text(SetupViewConstants.Texts.selectClassesText)
                    .font(.title)
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
                                .foregroundColor(
                                    self.selection.contains(index)
                                    ? SetupViewConstants.Colors.selectedClass
                                    : SetupViewConstants.Colors.unselectedClass
                                )
                        }
                    }
                }
            }
            .padding()
            .navigationBarTitle(SetupViewConstants.Texts.setupViewTitle, displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(
                leading: Button(action: {
                    showLogoutConfirmation = true
                }) {
                    Image(systemName: SetupViewConstants.Images.logoutIcon)
                        .resizable()
                        .frame(
                            width: SetupViewConstants.Constraints.logoutIconSize,
                            height: SetupViewConstants.Constraints.logoutIconSize
                        )
                        .foregroundColor(.white)
                        .bold()
                },
                trailing: NavigationLink(destination: ContentView(selection: Array(selection))) {
                    Text(SetupViewConstants.Texts.nextButton).foregroundStyle(Color.white).font(.headline)
                }
            )
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
        .environment(\.colorScheme, .dark)
    }
}
