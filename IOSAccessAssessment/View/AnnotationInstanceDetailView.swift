//
//  AnnotationInstanceDetailView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 6/30/25.
//
import SwiftUI

extension AnnotationView {
    @ViewBuilder
    func openAnnotationInstanceDetailView() -> some View {
        let isWay = Constants.ClassConstants.classes[sharedImageData.segmentedIndices[index]].isWay
        let selectedObject = annotationImageManager.annotatedDetectedObjects?.first(where: { $0.id == annotationImageManager.selectedObjectId })
        let disabledStatus = (!isWay || (selectedObject?.isAll ?? false))
        
        Button(action: {
            isShowingAnnotationInstanceDetailView = true
        }) {
            Image(systemName: AnnotationViewConstants.Images.ellipsisIcon)
        }
        .buttonStyle(.bordered)
        .disabled(disabledStatus)
    }
    
    // Will be used to display the details of the selected annotation instance.
    @ViewBuilder
    func annotationInstanceDetailView() -> some View {
        let selectedObjectId = self.annotationImageManager.selectedObjectId ?? UUID()
        let selectedObjectWidth: Binding<Float> = Binding(
            get: { self.annotationImageManager.selectedObjectWidth ?? 0.0 },
            set: { newValue in
                self.updateSelectedObjectWidth(selectedObjectId: selectedObjectId, width: newValue)
            }
        )
        let selectedObjectBreakage: Binding<Bool> = Binding(
            get: { self.annotationImageManager.selectedObjectBreakage ?? false },
            set: { newValue in
                print("New Value: \(newValue)")
                self.updateSelectedObjectBreakage(selectedObjectId: selectedObjectId, breakageStatus: newValue)
            }
        )
        
        AnnotationInstanceDetailView(
            selectedObjectId: selectedObjectId,
            selectedObjectWidth: selectedObjectWidth,
            selectedObjectBreakage: selectedObjectBreakage
        )
    }
}

struct AnnotationInstanceDetailView: View {
    var selectedObjectId: UUID
    @Binding var selectedObjectWidth: Float
    @Binding var selectedObjectBreakage: Bool
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Text("Annotation Instance Details")
                .font(.title)
                .padding()
            
            Form {
                Section(header: Text("Object ID")) {
                    Text(selectedObjectId.uuidString)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Width")) {
                    TextField("Width in meters", value: $selectedObjectWidth, formatter: NumberFormatter())
                        .keyboardType(.decimalPad)
                }
                
                Section(header: Text("Breakage Status")) {
                    Toggle(isOn: $selectedObjectBreakage) {
                        Text("Potential Breakage")
                    }
                }
            }
        }
    }
}
