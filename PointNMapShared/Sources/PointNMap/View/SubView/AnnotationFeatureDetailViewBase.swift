//
//  AnnotationFeatureDetailView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/28/25.
//

import SwiftUI
import Combine

public func AnnotationFeatureDetailLocationFormatter() -> NumberFormatter {
    let nf = NumberFormatter()
    nf.numberStyle = .decimal
    nf.maximumFractionDigits = 7
    nf.minimumFractionDigits = 7
    return nf
}

public enum AnnotationFeatureDetailViewConstants {
    public enum Texts {
        /// Alert texts
        public static let statusAlertTitleKey: String = "Error"
        public static let statusAlertDismissAlertSuffixKey: String = "Press OK to dismiss this alert."
        public static let statusAlertDismissButtonKey: String = "OK"
        
        /// Is Existing
        public static let isExistingTitle: String = "Is this an existing feature?"
        
        /// Invalid
        public static let invalidTextKey: String = "Invalid"
    }
    
    public enum Images {
        /// Alert images
        public static let statusAlertImageNameKey: String = "exclamationmark.triangle.fill"
    }
}

/**
    A view that displays detailed information about an accessibility feature annotation.
    Sub-view of the `AnnotationView`.
 */
public struct AnnotationFeatureDetailViewBase<
    Feature: EditableAccessibilityFeatureProtocol,
    LocationSection: View
    >: View {
    
    public enum AnnotationFeatureDetailViewError: Error, LocalizedError {
        case invalidAttributeValue(attribute: AccessibilityFeatureAttribute, message: String)
        
        public var errorDescription: String? {
            switch self {
            case .invalidAttributeValue(let attribute, let message):
                return "Invalid value for \(attribute.displayName): \(message)"
            }
        }
    }
    
    public struct AttributeErrorStatus {
        public var isError: Bool
        public var errorMessage: String
        
        public init(isError: Bool, errorMessage: String) {
            self.isError = isError
            self.errorMessage = errorMessage
        }
    }
    
    public class StatusViewModel: ObservableObject {
        @Published public var attributeStatusMap: [AccessibilityFeatureAttribute: AttributeErrorStatus] = [:]
        
        public func configure(accessibilityFeature: Feature) {
            let attributes = accessibilityFeature.accessibilityFeatureClass.kind.attributes
            var attributeStatusMap: [AccessibilityFeatureAttribute: AttributeErrorStatus] = [:]
            attributes.forEach {
                let initialStatus = AttributeErrorStatus(isError: false, errorMessage: "")
                attributeStatusMap[$0] = initialStatus
            }
            self.attributeStatusMap = attributeStatusMap
        }
        
        public func updateAttributeStatus(
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
    
    public var accessibilityFeature: Feature
    public let title: String
    private let locationSection: (Feature) -> LocationSection
    private let locationFormatter = AnnotationFeatureDetailLocationFormatter()
    
    @StateObject private var statusViewModel = AnnotationFeatureDetailViewBase.StatusViewModel()
    @FocusState private var focusedField: AccessibilityFeatureAttribute?
    /// Note: Fields such as pickers don't have built-in ways to update their UI based on user input. Hence we need to trigger a refresh manually when their value changes.
    @State private var refreshTrigger: Int = 0
    
    public init(
        accessibilityFeature: Feature,
        title: String,
        @ViewBuilder locationSection: @escaping (Feature) -> LocationSection
    ) {
        self.accessibilityFeature = accessibilityFeature
        self.title = title
        self.locationSection = locationSection
    }
    
    public var body: some View {
        VStack {
            Text(title)
                .font(.headline)
                .padding()
            
            Form {
                Section(header: Text(AnnotationViewBaseConstants.Texts.featureDetailViewIdKey)) {
                    Text(accessibilityFeature.id.uuidString)
                        .foregroundStyle(.secondary)
                }
                
                /**
                 Location Section
                 */
                locationSection(accessibilityFeature)
                
                /**
                 The Attributes Section
                 Instead of using a ForEach loop, we manually list out each attribute to have more control over the layout and presentation.
                 This allows us to customize the display for each attribute type as needed.
                 There isn't a large number of attributes, so this approach is manageable and provides better clarity.
                 */
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.width))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.width.displayName)) {
                        numberTextFieldView(attribute: .width)
                            .focused($focusedField, equals: .width)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.runningSlope))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.runningSlope.displayName)) {
                        numberTextFieldView(attribute: .runningSlope)
                            .focused($focusedField, equals: .runningSlope)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.crossSlope))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.crossSlope.displayName)) {
                        numberTextFieldView(attribute: .crossSlope)
                            .focused($focusedField, equals: .crossSlope)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.surfaceIntegrity))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.surfaceIntegrity.displayName)) {
                        pickerView(attribute: .surfaceIntegrity)
                            .focused($focusedField, equals: .surfaceIntegrity)
                            .id(refreshTrigger) // Refresh the Picker view when refreshTrigger changes
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.surfaceDisruption)) {
                    Section(header: Text(AccessibilityFeatureAttribute.surfaceDisruption.displayName)) {
                        numberTextFieldView(attribute: .surfaceDisruption)
                            .focused($focusedField, equals: .surfaceDisruption)
                            .id(refreshTrigger) // Refresh the Picker view when refreshTrigger changes
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.heightFromGround)) {
                    Section(header: Text(AccessibilityFeatureAttribute.heightFromGround.displayName)) {
                        numberTextFieldView(attribute: .heightFromGround)
                            .focused($focusedField, equals: .heightFromGround)
                    }
                }
                
                /// Experimental Attributes Section
                if (accessibilityFeature.accessibilityFeatureClass.kind.experimentalAttributes.contains(.lidarDepth)) {
                    Section(header: Text(AccessibilityFeatureAttribute.lidarDepth.displayName)) {
                        numberTextView(attribute: .lidarDepth)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.experimentalAttributes.contains(.latitudeDelta)) {
                    Section(header: Text(AccessibilityFeatureAttribute.latitudeDelta.displayName)) {
                        numberTextView(attribute: .latitudeDelta)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.experimentalAttributes.contains(.longitudeDelta)) {
                    Section(header: Text(AccessibilityFeatureAttribute.longitudeDelta.displayName)) {
                        numberTextView(attribute: .longitudeDelta)
                    }
                }
                
                /// Legacy Attributes Section
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.widthLegacy))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.widthLegacy.displayName)) {
                        numberTextFieldView(attribute: .widthLegacy)
                            .focused($focusedField, equals: .widthLegacy)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.runningSlopeLegacy))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.runningSlopeLegacy.displayName)) {
                        numberTextFieldView(attribute: .runningSlopeLegacy)
                            .focused($focusedField, equals: .runningSlopeLegacy)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.crossSlopeLegacy))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.crossSlopeLegacy.displayName)) {
                        numberTextFieldView(attribute: .crossSlopeLegacy)
                            .focused($focusedField, equals: .crossSlopeLegacy)
                    }
                }
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.widthFromImage))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.widthFromImage.displayName)) {
                        numberTextFieldView(attribute: .widthFromImage)
                            .focused($focusedField, equals: .widthFromImage)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.runningSlopeFromImage))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.runningSlopeFromImage.displayName)) {
                        numberTextFieldView(attribute: .runningSlopeFromImage)
                            .focused($focusedField, equals: .runningSlopeFromImage)
                    }
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.kind.attributes.contains(.crossSlopeFromImage))
                {
                    Section(header: Text(AccessibilityFeatureAttribute.crossSlopeFromImage.displayName)) {
                        numberTextFieldView(attribute: .crossSlopeFromImage)
                            .focused($focusedField, equals: .crossSlopeFromImage)
                    }
                }
            }
        }
        .onAppear {
            self.statusViewModel.configure(accessibilityFeature: accessibilityFeature)
            focusedField = nil
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
                        systemImage: AnnotationFeatureDetailViewConstants.Images.statusAlertImageNameKey
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
                            guard let newAttributeValue = attribute.value(from: newDoubleValue) else {
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
                return AnnotationFeatureDetailViewConstants.Texts.invalidTextKey
            }
            return String(attributeBindableValue)
        }()
        VStack {
            if (attributeStatus.isError) {
                /// A red colored error message
                HStack {
                    Label(
                        attributeStatus.errorMessage,
                        systemImage: AnnotationFeatureDetailViewConstants.Images.statusAlertImageNameKey
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
                        guard let newAttributeValue = attribute.value(from: newBoolValue) else {
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
    
    @ViewBuilder
    private func pickerView(attribute: AccessibilityFeatureAttribute) -> some View {
        Picker(
            attribute.displayName,
            selection: Binding<AnyCategoricalValue?>(
                get: {
                    guard case .categorical(let category) = accessibilityFeature.attributeValues[attribute] else {
                        return attribute.categoricalOptions().first
                    }
                    return category
                },
                set: { newValue in
                    guard let newValue else { return }
                    do {
                        let newCategoricalValue: AccessibilityFeatureAttribute.Value = .categorical(newValue)
                        try accessibilityFeature.setAttributeValue(newCategoricalValue, for: attribute)
                        refreshTrigger += 1 // Trigger a refresh to update the Picker's displayed value
                    } catch {
                        setAttributeStatusErrorText(for: attribute, message: "\(error.localizedDescription)")
                    }
                }
        )) {
            ForEach(attribute.categoricalOptions(), id: \.self) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.menu)
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
