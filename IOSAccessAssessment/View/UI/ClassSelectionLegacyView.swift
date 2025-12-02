//
//  ClassSelectionView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 6/17/25.
//
import SwiftUI

// Extension for loading the ClassSelectionView as sheet
extension AnnotationLegacyView {
    @ViewBuilder
    func classSelectionView() -> some View {
        if let selectedClassIndex = selectedClassIndex {
            let filteredClasses = selectedClassIndices.map { Constants.SelectedAccessibilityFeatureConfig.classNames[$0] }
            
            // mapping between filtered and non-filtered
            let selectedFilteredIndex = selectedClassIndices.firstIndex(of: sharedImageData.segmentedIndices[selectedClassIndex]) ?? 0
            
            let selectedClassBinding: Binding<Array<Int>.Index> = Binding(
                get: { selectedFilteredIndex },
                set: { newValue in
                    let originalIndex = selectedClassIndices[newValue]
                    // Update the segmentedIndices inside sharedImageData
                    sharedImageData.segmentedIndices[selectedClassIndex] = originalIndex
                }
            )
            
            ClassSelectionView(
                classes: filteredClasses,
                selectedClass: selectedClassBinding
            )
        }
    }
}

struct ClassSelectionView: View {
    var classes: [String]
    @Binding var selectedClass: Int
    
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text(AnnotationLegacyViewConstants.Texts.selectCorrectAnnotationText)
                .font(.headline)
                .padding()

            List {
                ForEach(0..<classes.count, id: \.self) { index in
                    Button(action: {
                        selectedClass = index
                    }) {
                        HStack {
                            Text(classes[index])
                            Spacer()
                            if selectedClass == index {
                                Image(systemName: AnnotationLegacyViewConstants.Images.checkIcon)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            
            Button(action: {
                self.presentationMode.wrappedValue.dismiss()
            }) {
                Text(AnnotationLegacyViewConstants.Texts.doneText)
                    .padding()
            }
        }
    }
}
