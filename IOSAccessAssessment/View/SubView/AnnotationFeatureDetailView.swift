//
//  AnnotationFeatureDetailView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/28/25.
//

import SwiftUI

/**
    A view that displays detailed information about an accessibility feature annotation.
    Sub-view of the `AnnotationView`.
 */
struct AnnotationFeatureDetailView: View {
    enum Constants {
        enum Texts {
            /// Alert texts
            static let statusAlertTitleKey: String = "Error"
            static let statusAlertDismissAlertSuffixKey: String = "Press OK to dismiss this alert."
            static let statusAlertDismissButtonKey: String = "OK"
            
            /// Invalid
            static let invalidTextKey: String = "Invalid"
        }
        
        enum Images {
            /// Alert images
            static let statusAlertImageNameKey: String = "exclamationmark.triangle.fill"
        }
    }
    
    enum AnnotationFeatureDetailViewError: Error, LocalizedError {
        case invalidAttributeValue(attribute: AccessibilityFeatureAttribute, message: String)
        
        var errorDescription: String? {
            switch self {
            case .invalidAttributeValue(let attribute, let message):
                return "Invalid value for \(attribute.displayName): \(message)"
            }
        }
    }
    
    struct AttributeErrorStatus {
        var isError: Bool
        var errorMessage: String
        
        init(isError: Bool, errorMessage: String) {
            self.isError = isError
            self.errorMessage = errorMessage
        }
    }
    
    class StatusViewModel: ObservableObject {
        @Published var attributeStatusMap: [AccessibilityFeatureAttribute: AttributeErrorStatus] = [:]
        
        func configure(accessibilityFeature: EditableAccessibilityFeature) {
            let attributes = accessibilityFeature.accessibilityFeatureClass.attributes
            var attributeStatusMap: [AccessibilityFeatureAttribute: AttributeErrorStatus] = [:]
            attributes.forEach {
                let initialStatus = AttributeErrorStatus(isError: false, errorMessage: "")
                attributeStatusMap[$0] = initialStatus
            }
            self.attributeStatusMap = attributeStatusMap
        }
        
        func updateAttributeStatus(
            for attribute: AccessibilityFeatureAttribute,
            isError: Bool,
            errorMessage: String
        ) {
            if let _ = attributeStatusMap[attribute] {
                attributeStatusMap[attribute]?.isError = isError
                attributeStatusMap[attribute]?.errorMessage = errorMessage
            }
        }
    }
    
    var accessibilityFeature: EditableAccessibilityFeature
    let title: String
    
    @StateObject private var statusViewModel = AnnotationFeatureDetailView.StatusViewModel()
    @FocusState private var focusedField: AccessibilityFeatureAttribute?
    
    var locationFormatter: NumberFormatter = {
        var nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 7
        nf.minimumFractionDigits = 7
        return nf
    }()
    
    var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            
            Form {
                Section(header: Text(AnnotationViewConstants.Texts.featureDetailViewIdKey)) {
                    Text(accessibilityFeature.id.uuidString)
                        .foregroundStyle(.secondary)
                }
                
                /**
                 Location Section
                 */
                
                Section(header: Text(AnnotationViewConstants.Texts.featureDetailViewLocationKey)) {
                    if let featureLocation = accessibilityFeature.getLastLocationCoordinate() {
                        HStack {
                            Spacer()
                            Text(
                                locationFormatter.string(
                                    from: NSNumber(value: featureLocation.latitude)
                                ) ?? AnnotationFeatureDetailView.Constants.Texts.invalidTextKey
                            )
                            .padding(.horizontal)
                            Text(
                                locationFormatter.string(
                                    from: NSNumber(value: featureLocation.longitude)
                                ) ?? AnnotationFeatureDetailView.Constants.Texts.invalidTextKey
                            )
                            .padding(.horizontal)
                            Spacer()
                        }
                    } else {
                        Text(AnnotationFeatureDetailView.Constants.Texts.invalidTextKey)
                            .foregroundStyle(.secondary)
                    }
                }
                
                /**
                 The Attributes Section
                 Instead of using a ForEach loop, we manually list out each attribute to have more control over the layout and presentation.
                 This allows us to customize the display for each attribute type as needed.
                 There isn't a large number of attributes, so this approach is manageable and provides better clarity.
                 */
                
                if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.width))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.width.displayName)) {
                        numberTextFieldView(attribute: .width)
                            .focused($focusedField, equals: .width)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.runningSlope))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.runningSlope.displayName)) {
                        numberTextFieldView(attribute: .runningSlope)
                            .focused($focusedField, equals: .runningSlope)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.crossSlope))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.crossSlope.displayName)) {
                        numberTextFieldView(attribute: .crossSlope)
                            .focused($focusedField, equals: .crossSlope)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.surfaceIntegrity))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.surfaceIntegrity.displayName)) {
                        toggleView(attribute: .surfaceIntegrity)
                            .focused($focusedField, equals: .surfaceIntegrity)
                    }
                }
                
                /// Experimental Attributes Section
                if (accessibilityFeature.accessibilityFeatureClass.experimentalAttributes.contains(.lidarDepth)) {
                    Section(header: Text(AccessibilityFeatureAttribute.lidarDepth.displayName)) {
                        numberTextView(attribute: .lidarDepth)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.experimentalAttributes.contains(.latitudeDelta)) {
                    Section(header: Text(AccessibilityFeatureAttribute.latitudeDelta.displayName)) {
                        numberTextView(attribute: .latitudeDelta)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.experimentalAttributes.contains(.longitudeDelta)) {
                    Section(header: Text(AccessibilityFeatureAttribute.longitudeDelta.displayName)) {
                        numberTextView(attribute: .longitudeDelta)
                    }
                }
                
                /// Legacy Attributes Section
                if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.widthLegacy))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.widthLegacy.displayName)) {
                        numberTextFieldView(attribute: .widthLegacy)
                            .focused($focusedField, equals: .widthLegacy)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.runningSlopeLegacy))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.runningSlopeLegacy.displayName)) {
                        numberTextFieldView(attribute: .runningSlopeLegacy)
                            .focused($focusedField, equals: .runningSlopeLegacy)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.crossSlopeLegacy))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.crossSlopeLegacy.displayName)) {
                        numberTextFieldView(attribute: .crossSlopeLegacy)
                            .focused($focusedField, equals: .crossSlopeLegacy)
                    }
                }
            }
        }
        .onAppear {
            self.statusViewModel.configure(accessibilityFeature: accessibilityFeature)
        }
        .onTapGesture {
            // Dismiss the keyboard when tapping outside of a TextField
            focusedField = nil
        }
    }
    
    @ViewBuilder
    private func numberTextFieldView(attribute: AccessibilityFeatureAttribute) -> some View {
        let attributeStatus = statusViewModel.attributeStatusMap[attribute] ?? .init(isError: false, errorMessage: "")
        VStack {
            if (attributeStatus.isError) {
                /// A red colored error message
                HStack {
                    Label(
                        attributeStatus.errorMessage,
                        systemImage: AnnotationFeatureDetailView.Constants.Images.statusAlertImageNameKey
                    )
                        .foregroundStyle(.red)
                        .font(.caption)
                    Spacer()
                }
            }
            TextField(
                attribute.displayName,
                value: Binding(
                    get: {
                        guard let attributeValue = accessibilityFeature.attributeValues[attribute],
                              let attributeValue,
                              let attributeBindableValue = attributeValue.toDouble() else {
                            return 0.0
                        }
                        return attributeBindableValue
                    },
                    set: { newValue in
                        do {
                            let newDoubleValue = Double(newValue)
                            guard let newAttributeValue = attribute.valueFromDouble(newDoubleValue) else {
                                return
                            }
                            try accessibilityFeature.setAttributeValue(newAttributeValue, for: attribute)
                        } catch {
                            setAttributeStatusErrorText(for: attribute, message: "\(error.localizedDescription)")
                        }
                    }
                ),
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .keyboardType(.decimalPad)
        }
    }
    
    @ViewBuilder
    private func numberTextView(attribute: AccessibilityFeatureAttribute) -> some View {
        let attributeStatus = statusViewModel.attributeStatusMap[attribute] ?? .init(isError: false, errorMessage: "")
        let valueToDisplay: String = {
            guard let attributeValue = accessibilityFeature.experimentalAttributeValues[attribute],
                  let attributeValue,
                  let attributeBindableValue = attributeValue.toDouble() else {
                return AnnotationFeatureDetailView.Constants.Texts.invalidTextKey
            }
            return String(attributeBindableValue)
        }()
        VStack {
            if (attributeStatus.isError) {
                /// A red colored error message
                HStack {
                    Label(
                        attributeStatus.errorMessage,
                        systemImage: AnnotationFeatureDetailView.Constants.Images.statusAlertImageNameKey
                    )
                        .foregroundStyle(.red)
                        .font(.caption)
                    Spacer()
                }
            }
            Text(valueToDisplay)
        }
    }
    
    @ViewBuilder
    private func toggleView(attribute: AccessibilityFeatureAttribute) -> some View {
        Toggle(
            isOn: Binding(
                get: {
                    guard let attributeValue = accessibilityFeature.attributeValues[attribute],
                          let attributeValue,
                          let attributeBindableValue = attributeValue.toBool() else {
                        return false
                    }
                    return attributeBindableValue
                },
                set: { newValue in
                    do {
                        let newBoolValue = Bool(newValue)
                        guard let newAttributeValue = attribute.valueFromBool(newBoolValue) else {
                            return
                        }
                        try accessibilityFeature.setAttributeValue(newAttributeValue, for: attribute)
                    } catch {
                        setAttributeStatusErrorText(for: attribute, message: "\(error.localizedDescription)")
                    }
                }
            )
        ) {
            Text(attribute.displayName)
        }
    }
    
    private func setAttributeStatusErrorText(
        for attribute: AccessibilityFeatureAttribute, message: String
    ) {
        statusViewModel.updateAttributeStatus(for: attribute, isError: true, errorMessage: message)
        Task {
            do {
                try await Task.sleep(for: .seconds(2))
                statusViewModel.updateAttributeStatus(for: attribute, isError: false, errorMessage: "")
            } catch {
                print("Failed to reset attribute error status: \(error.localizedDescription)")
            }
        }
    }
}
