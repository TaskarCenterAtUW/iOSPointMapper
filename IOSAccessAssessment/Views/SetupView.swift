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
    private var isSelectionEmpty: Bool {
        return (self.selection.count == 0)
    }
    @State private var showLogoutConfirmation = false
    @EnvironmentObject var userState: UserStateViewModel
    @StateObject private var sharedImageData: SharedImageData = SharedImageData()
    @StateObject private var segmentationModel: SegmentationModel = SegmentationModel()
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text(SetupViewConstants.Texts.selectClassesText)
                    .font(.title)
                    .foregroundColor(.gray)
                
                List {
                    ForEach(0..<Constants.ClassConstants.classNames.count, id: \.self) { index in
                        Button(action: {
                            if self.selection.contains(index) {
                                self.selection.remove(index)
                            } else {
                                self.selection.insert(index)
                            }
                        }) {
                            Text(Constants.ClassConstants.classNames[index])
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
                trailing:
                    NavigationLink(destination: ContentView(selection: Array(selection))) {
                        Text(SetupViewConstants.Texts.nextButton)
                            .foregroundStyle(isSelectionEmpty ? Color.gray : Color.white)
                            .font(.headline)
                    }
                    .disabled(isSelectionEmpty)
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
            .onAppear {
                // This refresh is done asynchronously, because frames get added from the ContentView even after the refresh
                // This kind of delay should be fine, since the very first few frames of capture may not be necessary.
                // MARK: Discuss on the possibility of having an explicit refresh
                // instead of always refreshing when we end up in SetupView (could happen accidentally)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                    self.sharedImageData.refreshData()
                })
            }
        }
        .environmentObject(self.sharedImageData)
        .environmentObject(self.segmentationModel)
        .environment(\.colorScheme, .dark)
    }
}
