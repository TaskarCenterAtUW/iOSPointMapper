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
public struct CustomPicker<SelectionValue: Hashable, Content: View>: View {
    public let label: String
    @Binding public var selection: SelectionValue?
    public let isContainsAll: Bool
    public let content: () -> Content
    
    public init(label: String, selection: Binding<SelectionValue?>, isContainsAll: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self._selection = selection
        self.isContainsAll = isContainsAll
        self.content = content
    }
    
    public var body: some View {
        Picker(label, selection: $selection) {
            if (isContainsAll) {
                Text("All").tag(nil as SelectionValue?)
            }
            content()
        }
    }
}
