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
        let isWay = Constants.SelectedSegmentationConfig.classes[sharedImageData.segmentedIndices[index]].isWay
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
                self.updateSelectedObjectBreakage(selectedObjectId: selectedObjectId, breakageStatus: newValue)
            }
        )
        
        AnnotationInstanceDetailView(
            selectedObjectId: selectedObjectId,
            selectedObjectWidth: selectedObjectWidth,
            selectedObjectBreakage: selectedObjectBreakage
        )
    }
    
    // MARK: Width Field Demo: Temporary method to update the object width of the selected object
    func updateSelectedObjectWidth(selectedObjectId: UUID, width: Float) {
        if let selectedObject = annotationImageManager.annotatedDetectedObjects?.first(where: { $0.id == selectedObjectId }),
           let selectedObjectObject = selectedObject.object {
            selectedObjectObject.finalWidth = width
            annotationImageManager.selectedObjectWidth = width
        }
    }
    
    // MARK: Breakage Field Demo: Temporary method to update the object width of the selected object
    func updateSelectedObjectBreakage(selectedObjectId: UUID, breakageStatus: Bool) {
        if let selectedObject = annotationImageManager.annotatedDetectedObjects?.first(where: { $0.id == selectedObjectId }),
           let selectedObjectObject = selectedObject.object {
            selectedObjectObject.finalBreakage = breakageStatus
            annotationImageManager.selectedObjectBreakage = breakageStatus
        }
    }
}

struct AnnotationInstanceDetailView: View {
    var selectedObjectId: UUID
    @Binding var selectedObjectWidth: Float
    @Binding var selectedObjectBreakage: Bool
    
    @Environment(\.presentationMode) var presentationMode
    
    var numberFormatter: NumberFormatter = {
        var nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf
    }()
    
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
                    TextField("Width in meters", value: $selectedObjectWidth, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
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
