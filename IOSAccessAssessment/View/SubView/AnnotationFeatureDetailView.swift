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
    var accessibilityFeature: AccessibilityFeature
    let title: String
    
    @FocusState private var focusedField: AccessibilityFeatureAttribute?
    
    var locationFormatter: NumberFormatter = {
        var nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 6
        nf.minimumFractionDigits = 6
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
                if let calculatedLocation = accessibilityFeature.calculatedLocation {
                    Section(header: Text(AnnotationViewConstants.Texts.featureDetailViewLocationKey)) {
                        HStack {
                            Spacer()
                            Text(
                                locationFormatter.string(
                                    from: NSNumber(value: calculatedLocation.latitude)
                                ) ?? "N/A"
                            )
                                .padding(.horizontal)
                            Text(
                                locationFormatter.string(
                                    from: NSNumber(value: calculatedLocation.longitude)
                                ) ?? "N/A"
                            )
                                .padding(.horizontal)
                            Spacer()
                        }
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
            }
        }
        .onTapGesture {
            // Dismiss the keyboard when tapping outside of a TextField
            focusedField = nil
        }
    }
    
    @ViewBuilder
    private func numberTextFieldView(attribute: AccessibilityFeatureAttribute) -> some View {
        TextField(
            attribute.displayName,
            value: Binding(
                get: {
                    attribute.getDouble(from: accessibilityFeature.finalAttributeValues[attribute])
                },
                set: { newValue in
                    accessibilityFeature.finalAttributeValues[attribute] = attribute.createFromDouble(newValue)
                }
            ),
            format: .number
        )
        .textFieldStyle(.roundedBorder)
        .keyboardType(.decimalPad)
    }
    
    @ViewBuilder
    private func toggleView(attribute: AccessibilityFeatureAttribute) -> some View {
        Toggle(
            isOn: Binding(
                get: {
                    attribute.getBool(from: accessibilityFeature.finalAttributeValues[attribute])
                },
                set: { newValue in
                    accessibilityFeature.finalAttributeValues[attribute] = attribute.createFromBool(newValue)
                }
            )
        ) {
            Text(attribute.displayName)
        }
    }
}
