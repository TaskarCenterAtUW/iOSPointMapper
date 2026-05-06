//
//  AnnotationFeatureDetailView.swift
//  IOSAccessAssessment
//
//  Created by Himanshu on 11/28/25.
//

import SwiftUI
import PointNMapShared

enum AnnotationMappedFeatureDetailViewConstants {
    enum Texts {
        /// Is Existing
        static let isExistingTitle: String = "Is this an existing feature?"
        
        /// Invalid
        static let invalidTextKey: String = "Invalid"
    }
    
    enum Images {
        /// Alert images
        static let statusAlertImageNameKey: String = "exclamationmark.triangle.fill"
    }
}

/**
    A view that displays detailed information about an accessibility feature annotation.
    Sub-view of the `AnnotationView`.
 */
@ViewBuilder
func AnnotationFeatureDetailView(
    accessibilityFeature: MappedEditableAccessibilityFeature,
    title: String
) -> some View {
    AnnotationFeatureDetailViewBase(
        accessibilityFeature: accessibilityFeature, title: title
    ) { feature in
        let locationFormatter = AnnotationFeatureDetailLocationFormatter()
        Section(header: Text(AnnotationViewConstants.Texts.featureDetailViewLocationKey)) {
            if let featureLocation = accessibilityFeature.getLastLocationCoordinate() {
                VStack {
                    HStack {
                        Spacer()
                        Text(
                            locationFormatter.string(
                                from: NSNumber(value: featureLocation.latitude)
                            ) ?? AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey
                        )
                        .padding(.horizontal)
                        Text(
                            locationFormatter.string(
                                from: NSNumber(value: featureLocation.longitude)
                            ) ?? AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey
                        )
                        .padding(.horizontal)
                        Spacer()
                    }
                    Divider()
                    HStack {
                        Spacer()
                        Toggle(isOn: Binding(
                            get: { accessibilityFeature.isExisting && accessibilityFeature.oswElement != nil },
                            set: { newValue in
                                accessibilityFeature.setIsExisting(newValue)
                            }
                        )) {
                            Text(AnnotationMappedFeatureDetailViewConstants.Texts.isExistingTitle)
                        }
                        .disabled(accessibilityFeature.oswElement == nil)
                        .foregroundStyle(accessibilityFeature.oswElement == nil ? .secondary : .primary)
                        .strikethrough(accessibilityFeature.oswElement == nil, pattern: .solid)
                        Spacer()
                    }
                    if let oswElement = accessibilityFeature.oswElement {
                        HStack {
                            Spacer()
                            Text("TDEI Element ID: \(oswElement.id)")
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top, 4)
                        .padding(.bottom, 4)
                    }
                }
            } else {
                Text(AnnotationMappedFeatureDetailViewConstants.Texts.invalidTextKey)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
