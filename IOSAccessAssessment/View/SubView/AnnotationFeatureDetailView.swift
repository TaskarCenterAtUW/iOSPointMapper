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
    
    var numberFormatter: NumberFormatter = {
        var nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf
    }()
    
    var body: some View {
        VStack {
            Text(accessibilityFeature.accessibilityFeatureClass.name)
                .font(.headline)
                .padding()
            
            Form {
                Section(header: Text(AnnotationViewConstants.Texts.featureDetailViewIdKey)) {
                    Text(accessibilityFeature.id.uuidString)
                        .foregroundStyle(.secondary)
                }
                
                /**
                 The Attributes Section
                 Instead of using a ForEach loop, we manually list out each attribute to have more control over the layout and presentation.
                 This allows us to customize the display for each attribute type as needed.
                 There isn't a large number of attributes, so this approach is manageable and provides better clarity.
                 */
                
                if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.width))
                {
                    numberTextFieldView(attribute: .width)
                }
                
                if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.runningSlope))
                {
                    numberTextFieldView(attribute: .runningSlope)
                }
            }
            
            if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.crossSlope))
            {
                numberTextFieldView(attribute: .crossSlope)
            }
            
            if (accessibilityFeature.accessibilityFeatureClass.attributes.contains(.surfaceIntegrity))
            {
                toggleView(attribute: .surfaceIntegrity)
            }
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
        .keyboardType(.decimalPad)
        .submitLabel(.done)
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
