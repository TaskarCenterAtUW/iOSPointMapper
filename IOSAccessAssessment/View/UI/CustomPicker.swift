//
//  CustomPicker.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/28/25.
//

import SwiftUI

/**
 Custom picker with a select all option that binds nil to "All".
 */
struct CustomPicker<SelectionValue: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: SelectionValue?
    let isContainsAll: Bool
    let content: () -> Content
    
    var body: some View {
        Picker(label, selection: $selection) {
            if (isContainsAll) {
                Text("All").tag(nil as SelectionValue?)
            }
            content()
        }
    }
}
