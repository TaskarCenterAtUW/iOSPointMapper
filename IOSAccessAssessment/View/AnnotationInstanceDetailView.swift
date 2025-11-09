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
        let isWay = Constants.SelectedAccessibilityFeatureConfig.classes[sharedImageData.segmentedIndices[index]].isWay
        let selectedObject = annotationImageManager.annotatedDetectedObjects?.first(where: { $0.id == annotationImageManager.selectedObjectId })
        let disabledStatus = (!isWay || (selectedObject?.isAll ?? false))
        
        Button(action: {
            isShowingAnnotationInstanceDetailView = true
        }) {
            Image(systemName: AnnotationViewConstants.Images.ellipsisIcon)
        }
        .buttonStyle(.bordered)
        .disabled(disabledStatus)
        .padding(.horizontal, 5)
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
        let selectedObjectSlope: Binding<Float> = Binding(
            get: { self.annotationImageManager.selectedObjectSlope ?? 0.0 },
            set: { newValue in
                self.updateSelectedObjectSlope(selectedObjectId: selectedObjectId, slope: newValue)
            }
        )
        let selectedObjectCrossSlope: Binding<Float> = Binding(
            get: { self.annotationImageManager.selectedObjectCrossSlope ?? 0.0 },
            set: { newValue in
                self.updateSelectedObjectCrossSlope(selectedObjectId: selectedObjectId, crossSlope: newValue)
            }
        )
        
        AnnotationInstanceDetailView(
            selectedObjectId: selectedObjectId,
            selectedObjectWidth: selectedObjectWidth,
            selectedObjectBreakage: selectedObjectBreakage,
            selectedObjectSlope: selectedObjectSlope,
            selectedObjectCrossSlope: selectedObjectCrossSlope
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
            
    // MARK: Slope Field Demo: Temporary method to update the slope of the selected object
    func updateSelectedObjectSlope(selectedObjectId: UUID, slope: Float) {
        if let selectedObject = annotationImageManager.annotatedDetectedObjects?.first(where: { $0.id == selectedObjectId }),
           let selectedObjectObject = selectedObject.object {
            selectedObjectObject.finalSlope = slope
            annotationImageManager.selectedObjectSlope = slope
        }
    }
    
    // MARK: Cross Slope Field Demo: Temporary method to update the cross slope of the selected object
    func updateSelectedObjectCrossSlope(selectedObjectId: UUID, crossSlope: Float) {
        if let selectedObject = annotationImageManager.annotatedDetectedObjects?.first(where: { $0.id == selectedObjectId }),
           let selectedObjectObject = selectedObject.object {
            selectedObjectObject.finalCrossSlope = crossSlope
            annotationImageManager.selectedObjectCrossSlope = crossSlope
        }
    }
}

struct AnnotationInstanceDetailView: View {
    var selectedObjectId: UUID
    @Binding var selectedObjectWidth: Float
    @Binding var selectedObjectBreakage: Bool
    @Binding var selectedObjectSlope: Float
    @Binding var selectedObjectCrossSlope: Float
    
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
                
                Section(header: Text("Slope")) {
                    TextField("Slope in degrees", value: $selectedObjectSlope, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                }
                
                Section(header: Text("Cross Slope")) {
                    TextField("Cross Slope in degrees", value: $selectedObjectCrossSlope, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                }
            }
        }
    }
}
